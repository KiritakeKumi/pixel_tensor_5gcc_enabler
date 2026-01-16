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

PARENT_ID=20033
CHILD_IDS="1435 1436"

TABLE_CHECK=$($SQLITE "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name='carrier_parent';" 2>&1) || {
    ui_print "! sqlite3 error during table check: $TABLE_CHECK"
    abort "Failed to open cfg.db!"
}
ui_print "- Table check result: $TABLE_CHECK"
[ "$TABLE_CHECK" = "carrier_parent" ] || abort "Table carrier_parent not found in cfg.db!"

RF_TABLE_CHECK=$($SQLITE "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name='regional_fallback';" 2>&1) || {
    ui_print "! sqlite3 error during table check: $RF_TABLE_CHECK"
    abort "Failed to open cfg.db!"
}
ui_print "- Table check result: $RF_TABLE_CHECK"
[ "$RF_TABLE_CHECK" = "regional_fallback" ] || abort "Table regional_fallback not found in cfg.db!"

TABLE_INFO=$($SQLITE "$DB_PATH" "PRAGMA table_info(carrier_parent);" 2>&1) || {
    ui_print "! sqlite3 error during table_info:"
    ui_print "$TABLE_INFO"
    abort "Failed to open cfg.db!"
}
ui_print "- carrier_parent table_info:"
ui_print "$TABLE_INFO"

SCHEMA=$($SQLITE "$DB_PATH" "SELECT sql FROM sqlite_master WHERE type='table' AND name='carrier_parent';" 2>&1)
ui_print "- carrier_parent schema:"
ui_print "$SCHEMA"

SAMPLE_ROWS=$($SQLITE "$DB_PATH" "SELECT * FROM carrier_parent LIMIT 5;" 2>&1)
ui_print "- carrier_parent sample rows (up to 5):"
ui_print "$SAMPLE_ROWS"

echo "$TABLE_INFO" | grep -q "|carrier_id|" || abort "Column carrier_id not found in carrier_parent!"
echo "$TABLE_INFO" | grep -q "|parent_id|" || abort "Column parent_id not found in carrier_parent!"
RF_TABLE_INFO=$($SQLITE "$DB_PATH" "PRAGMA table_info(regional_fallback);" 2>&1) || {
    ui_print "! sqlite3 error during table_info (regional_fallback):"
    ui_print "$RF_TABLE_INFO"
    abort "Failed to open cfg.db!"
}
echo "$RF_TABLE_INFO" | grep -q "|carrier_id|" || abort "Column carrier_id not found in regional_fallback!"
ui_print "- Target parent_id: $PARENT_ID"
ui_print "- Target child carrier_ids: $CHILD_IDS"

SQL="
PRAGMA journal_mode=delete;
PRAGMA busy_timeout=2000;
-- Insert/replace parent mapping
INSERT OR REPLACE INTO carrier_parent (carrier_id, parent_id) VALUES
  (1435, $PARENT_ID),
  (1436, $PARENT_ID);
SELECT changes();
SELECT 'after', carrier_id, parent_id FROM carrier_parent WHERE carrier_id IN (1435, 1436);
-- Update regional_fallback default (replace 0 with parent_id)
UPDATE regional_fallback SET carrier_id = $PARENT_ID WHERE carrier_id = '0' OR country_code = '0';
SELECT 'after_fallback', country_code, carrier_id FROM regional_fallback LIMIT 5;
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
