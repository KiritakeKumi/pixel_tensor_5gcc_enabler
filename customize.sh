# Ensure installation is run from the Magisk app (recovery is not supported)
if $BOOTMODE; then
    ui_print "- Installing from Magisk app"
else
    ui_print "*********************************************************"
    ui_print "! Install from recovery is NOT supported"
    ui_print "! Please install from Magisk app"
    abort "*********************************************************"
fi

ui_print "- Preparing cfg.db copy"
rm -f $MODPATH/system/vendor/firmware/carrierconfig/cfg.db || abort "Failed to delete old cfg.db!"
chmod +x $MODPATH/tools/sqlite3 || abort "Failed to change chmod to +x for sqlite3!"
cp -a /vendor/firmware/carrierconfig/cfg.db $MODPATH/system/vendor/firmware/carrierconfig/ || abort "Failed to copy cfg.db!"

DB_PATH="$MODPATH/system/vendor/firmware/carrierconfig/cfg.db"
SQLITE="$MODPATH/tools/sqlite3"
rm -f "$DB_PATH-wal" "$DB_PATH-shm" 2>/dev/null
ui_print "- Using sqlite3: $SQLITE"
ui_print "- DB path: $DB_PATH"

FALLBACK_CARRIER_ID=656
TABLE_CHECK=$($SQLITE "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name='regional_fallback';" 2>&1) || {
    ui_print "! sqlite3 error during table check: $TABLE_CHECK"
    abort "Failed to open cfg.db!"
}
ui_print "- Table check result: $TABLE_CHECK"
[ "$TABLE_CHECK" = "regional_fallback" ] || abort "Table regional_fallback not found in cfg.db!"

TABLE_INFO=$($SQLITE "$DB_PATH" "PRAGMA table_info(regional_fallback);" 2>&1) || {
    ui_print "! sqlite3 error during table_info:"
    ui_print "$TABLE_INFO"
    abort "Failed to open cfg.db!"
}
ui_print "- regional_fallback table_info:"
ui_print "$TABLE_INFO"

SCHEMA=$($SQLITE "$DB_PATH" "SELECT sql FROM sqlite_master WHERE type='table' AND name='regional_fallback';" 2>&1)
ui_print "- regional_fallback schema:"
ui_print "$SCHEMA"

SAMPLE_ROWS=$($SQLITE "$DB_PATH" "SELECT * FROM regional_fallback LIMIT 5;" 2>&1)
ui_print "- regional_fallback sample rows (up to 5):"
ui_print "$SAMPLE_ROWS"

echo "$TABLE_INFO" | grep -q "|carrier_id|" || abort "Column carrier_id not found in regional_fallback!"

FILTER_COL=""
case "$TABLE_INFO" in
  *"|carrier_info|"*) FILTER_COL="carrier_info" ;;
  *"|carrierid|"*) FILTER_COL="carrierid" ;;
  *"|carrier_id|"*) FILTER_COL="carrier_id" ;;
esac
if [ -z "$FILTER_COL" ]; then
    ui_print "! Could not detect carrier key column in regional_fallback."
    abort "Unsupported regional_fallback schema, cannot patch."
fi
ui_print "- Using carrier key column: $FILTER_COL"

# Decide the update condition based on available columns
UPDATE_COND=""
if [ "$FILTER_COL" = "carrier_info" ] || [ "$FILTER_COL" = "carrierid" ]; then
    UPDATE_COND="$FILTER_COL = 23820"
else
    # Table only has carrier_id/country_code; replace legacy 0 fallback with Telia
    UPDATE_COND="carrier_id = '0' OR country_code = '0'"
fi
ui_print "- Using update condition: $UPDATE_COND"

SQL="
PRAGMA journal_mode=delete;
PRAGMA busy_timeout=2000;
-- Force fallback carrier to Telia (carrier_id = 656)
UPDATE regional_fallback
SET carrier_id = $FALLBACK_CARRIER_ID
WHERE $UPDATE_COND;
SELECT changes();
SELECT 'after', country_code, carrier_id FROM regional_fallback LIMIT 5;
"
PATCH_RESULT=$($SQLITE "$DB_PATH" "$SQL" 2>&1) || {
    ui_print "! sqlite3 error during patch:"
    ui_print "$PATCH_RESULT"
    abort "Failed to patch cfg.db!"
}
ui_print "- Patch output:"
ui_print "$PATCH_RESULT"

rm -f $MODPATH/tools/sqlite3 || abort "Failed to delete sqlite3!"

chcon u:object_r:vendor_fw_file:s0 $MODPATH/system/vendor/firmware/carrierconfig/cfg.db || ui_print "! Failed to set SELinux context."
