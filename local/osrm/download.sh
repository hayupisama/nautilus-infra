#!/bin/sh
# Telecharge l'extrait OSM (service osrm-download, image curl) dans /data, verifie son empreinte MD5.
# Relancable : ne retelecharge rien si l'extrait present (ou deja prepare) correspond a OSRM_PBF_URL + OSRM_PBF_MD5.
set -eu

: "${OSRM_PBF_URL:?OSRM_PBF_URL manquant}"
: "${OSRM_PBF_MD5:?OSRM_PBF_MD5 manquant}"
cd /data
stamp="$OSRM_PBF_URL $OSRM_PBF_MD5"

if [ "$(cat download.ok 2>/dev/null)" = "$stamp" ]; then
  if [ -f region.osm.pbf ]; then
    echo "Extrait deja present ($OSRM_PBF_URL) : telechargement ignore."
    exit 0
  fi
  # Extrait supprime apres preparation (gain de place, cache de la CI) : inutile tant que les donnees sont a jour
  case "$(cat prepare.ok 2>/dev/null)" in
    "$stamp "*) echo "Donnees OSRM deja preparees pour cet extrait : telechargement ignore."; exit 0 ;;
  esac
fi

echo "Telechargement de $OSRM_PBF_URL ..."
rm -f region.osm.pbf.part download.ok
curl -fL --retry 3 --retry-delay 5 --no-progress-meter -o region.osm.pbf.part "$OSRM_PBF_URL"
echo "$OSRM_PBF_MD5  region.osm.pbf.part" | md5sum -c -
mv region.osm.pbf.part region.osm.pbf
echo "$stamp" > download.ok
echo "Extrait telecharge et verifie."
