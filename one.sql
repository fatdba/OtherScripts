def generate_csv_and_pdf_reports_for_the_drift_tables(secrets_client, reporting_db_secret_arn, table_names_list, scan_id):
    """
    Function to gnereate CSV and pdf reports from the tables in drift reporting database
    secrets_client: Parameter to connect to Drift Reporting DB
    table_names_list: list of the all the drift tables to generate CSV and PDf reports from.
    scan_id: Represents the Sacn ID for this current lambda invocation. And Scan ID will be incremented with each invocation.
    """
    #Creates S3 bucket if not exist for storing the CSV and PDF reports of drift DB
    s3_resource = boto3.resource('s3')
    s3_bucket_name = 'edm-db-drift-detection-reports-'+os.getenv('environment')
    bucket = s3_resource.Bucket(s3_bucket_name)
    if bucket.creation_date:
        print("s3 bucket: "+s3_bucket_name+' Exists')
    else:
        response = bucket.create(CreateBucketConfiguration={'LocationConstraint': 'us-east-2'})
    s3_client = boto3.client('s3')

    #using font lib for calculating Sizes for pdf files
    font = ImageFont.load_default()

    #Looping Through Tables
    for each_table in table_names_list:
        print(each_table)
        #get table data
        sql = f"""
        select*from {each_table} where scanid = {str(scan_id)}::varchar;
        """
        print("before_run_query_using_secrets")
        result = pgs.run_query_using_secrets(secrets_client, reporting_db_secret_arn, sql)
        print("after_run_query_using_secrets")
        print(result)
        print("printresult")
        result_list = [each._asdict() for each in result]
        
        # added by Prashant 
        if not result:
            # Handle the case where the result is empty (no rows returned)
            print(f"No data found for {each_table}")
            continue
            
        #Parse Db table data and create CSV and PDF files
        header_list = [str(i) for i in result[0]._asdict().keys()]
        Column_sizes = [font.getsize(str(i)) for i in result[0]._asdict().keys()]

        file_name = str(each_table)+'_scan_'+str(scan_id)+'.csv'
        file_path = "/tmp/"+file_name

        pdf_file_name = str(each_table)+'_scan_'+str(scan_id)+'.pdf'
        pdf_file_path = "/tmp/"+pdf_file_name
        file_exists = os.path.exists(file_path)
        if not file_exists:
            #Creates CSV files
            with open(file_path,"w") as file:
                writer_object = csv.writer(file)
                writer_object.writerow(header_list)
                for each in result_list:
                    writer_object.writerow([str(j) for j in each.values()])
                    #calculating the column sizes for putting table data into pdf
                    index = 0
                    for i in each.values():
                        if Column_sizes[index][0] < font.getsize(str(i))[0]:
                            Column_sizes[index] = font.getsize(str(i))
                        index += 1
                file.close()
        else:
            #Updates CSV files
            with open(file_path,"a+") as file:
                writer_object = csv.writer(file)
                for each in result_list:
                    writer_object.writerow([str(j) for j in each.values()])
                    #calculating the column sizes for putting table data into pdf
                    index = 0
                    for i in each.values():
                        if Column_sizes[index][0] < font.getsize(str(i))[0]:
                            Column_sizes[index] = font.getsize(str(i))
                        index += 1
                file.close()
        file_exists = os.path.exists(file_path)
        #calculating max cel height height and total width of the page
        total_width = 0
        max_column_hieght = 0
        for each in Column_sizes:
            total_width += each[0]
            if max_column_hieght < each[1]:
                max_column_hieght = each[1]
        if file_exists:
            #Converts CSV file to PDF file
            convert(file_path, pdf_file_path, align='L', line_height=max_column_hieght, Column_sizes=Column_sizes, total_width=total_width+50)
            
            #Uploading CSV and PDF files to the S3 Bucket
            s3_client.upload_file(file_path, s3_bucket_name, 'csv_files/{}'.format(file_name))
            s3_client.upload_file(pdf_file_path, s3_bucket_name, 'pdf_files/{}'.format(pdf_file_name))
