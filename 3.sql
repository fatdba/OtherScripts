grep "$(date -d '5 days ago' '+%Y-%m-%d')" /path/to/alert_log_file | awk -v d="$(date -d '5 days ago' '+%Y-%m-%d')" '$1 >= d'
