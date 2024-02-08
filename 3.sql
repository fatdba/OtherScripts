original_log="/path/to/original_alert_log_file"
new_log="/path/to/new_alert_log_file"

# Extract the last 5 days' entries and redirect them to a new file
grep "$(date -d '5 days ago' '+%Y-%m-%d')" "$original_log" | \
  awk -v d="$(date -d '5 days ago' '+%Y-%m-%d')" '$1 >= d' > "$new_log"
