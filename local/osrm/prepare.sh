#!/bin/sh
# Prepare les donnees OSRM (service osrm-prepare, image osrm-backend) : extract, partition, customize (MLD).
# Relancable : ne refait rien si les donnees presentes correspondent deja a l'extrait, au profil et a la version d'OSRM.
set -eu

profile="/opt/${OSRM_PROFILE:-car}.lua"
cd /data
stamp="$(cat download.ok) $profile $(osrm-extract --version)"

if [ -f region.osrm.mldgr ] && [ "$(cat prepare.ok 2>/dev/null)" = "$stamp" ]; then
  echo "Donnees OSRM a jour : preparation ignoree."
  exit 0
fi
[ -f region.osm.pbf ] || { echo "region.osm.pbf absent : supprimer download.ok du volume puis relancer." >&2; exit 1; }

echo "Preparation OSRM (profil $profile), plusieurs minutes ..."
rm -f prepare.ok region.osrm*
start=$(date +%s)
osrm-extract -p "$profile" region.osm.pbf
osrm-partition region.osrm
osrm-customize region.osrm
echo "$stamp" > prepare.ok
echo "Preparation terminee en $(( $(date +%s) - start )) s."
