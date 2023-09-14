def generate_csv_and_pdf_reports_for_the_drift_tables(secrets_client, reporting_db_secret_arn, table_names_list, scan_id):
    # ... (other parts of the function remain the same) ...

    # Looping Through Tables
    for each_table in table_names_list:
        # ... (previous code for querying and preparing data) ...

        file_name = str(each_table)+'_scan_'+str(scan_id)+'.csv'
        file_path = "/tmp/"+file_name

        pdf_file_name = str(each_table)+'_scan_'+str(scan_id)+'.pdf'
        pdf_file_path = "/tmp/"+pdf_file_name
        file_exists = os.path.exists(file_path)

        # Always create an empty CSV file, regardless of whether result_list is empty or not
        with open(file_path, "w") as file:
            writer_object = csv.writer(file)
            writer_object.writerow(header_list)
        # Close the file immediately to create an empty CSV
        file.close()

        # ... (continue with the rest of the code for PDF generation and S3 upload) ...
