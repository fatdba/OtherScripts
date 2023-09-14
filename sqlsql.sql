import os
import csv
import boto3
from PIL import ImageFont
from fpdf import FPDF
from tempfile import NamedTemporaryFile

def generate_csv_and_pdf_reports_for_the_drift_tables(secrets_client, reporting_db_secret_arn, table_names_list, scan_id):
    """
    Function to generate CSV and pdf reports from the tables in the drift reporting database.
    secrets_client: Parameter to connect to the Drift Reporting DB.
    table_names_list: List of all the drift tables to generate CSV and PDF reports from.
    scan_id: Represents the Scan ID for this current lambda invocation. Scan ID will be incremented with each invocation.
    """
    # ... (Previous code)

    # Looping Through Tables
    for each_table in table_names_list:
        print(each_table)
        # Get table data
        sql = f"""
        SELECT * FROM {each_table} WHERE scanid = {str(scan_id)}::varchar;
        """
        print("before_run_query_using_secrets")
        result = pgs.run_query_using_secrets(secrets_client, reporting_db_secret_arn, sql)
        print("after_run_query_using_secrets")
        print(result)
        print("printresult")
        result_list = [each._asdict() for each in result]

        # Always create CSV and PDF reports, even if the result is empty
        # Create an empty CSV file
        header_list = [str(i) for i in result[0]._asdict().keys()]
        Column_sizes = [font.getsize(str(i)) for i in result[0]._asdict().keys()]
        file_name = str(each_table) + '_scan_' + str(scan_id) + '.csv'
        file_path = "/tmp/" + file_name

        pdf_file_name = str(each_table) + '_scan_' + str(scan_id) + '.pdf'
        pdf_file_path = "/tmp/" + pdf_file_name

        # Create or update CSV files
        with open(file_path, "w") as file:
            writer_object = csv.writer(file)
            writer_object.writerow(header_list)
            for each in result_list:
                writer_object.writerow([str(j) for j in each.values()])
                # Calculating the column sizes for putting table data into pdf
                index = 0
                for i in each.values():
                    if Column_sizes[index][0] < font.getsize(str(i))[0]:
                        Column_sizes[index] = font.getsize(str(i))
                    index += 1
            file.close()

        # Calculating max cell height and total width of the page
        total_width = 0
        max_column_height = 0
        for each in Column_sizes:
            total_width += each[0]
            if max_column_height < each[1]:
                max_column_height = each[1]

        # Convert CSV file to PDF file
        convert(file_path, pdf_file_path, align='L', line_height=max_column_height, Column_sizes=Column_sizes,
                total_width=total_width + 50)

        # Uploading CSV and PDF files to the S3 Bucket
        s3_client.upload_file(file_path, s3_bucket_name, 'csv_files/{}'.format(file_name))
        s3_client.upload_file(pdf_file_path, s3_bucket_name, 'pdf_files/{}'.format(pdf_file_name))
