# Set the path to the original alert log file and the new file
original_log="/path/to/original_alert_log_file"
new_log="/path/to/new_alert_log_file"

# Extract all entries from the last 5 days and redirect them to a new file
sed -n "/$(date -d '5 days ago' '+%Y-%m-%d')/,/$(date '+%Y-%m-%d')/p" "$original_log" > "$new_log"
