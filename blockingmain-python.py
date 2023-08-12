import cx_Oracle

# Database connection details
db_username = "system"
db_password = "xxxx"
db_host = "xxx"
db_port = "1521"
db_service = "xxxx"

# SQL file path
sql_file_path = "/home/oracle/xxxxx.sql"

# Establishing a database connection
dsn = cx_Oracle.makedsn(db_host, db_port, service_name=db_service)
connection = cx_Oracle.connect(user=db_username, password=db_password, dsn=dsn)

bold_start = "\033[1m"
color_green = "\033[32m"
reset_format = "\033[0m"

def print_colored(text, color_code):
    colored_text = "{}{}{}".format(color_code, text, reset_format)
    print(colored_text)

banner = """
=========================================================
      Locking Stats Report
        Author: Prashant Dixit 
        Version : 1.0
       Date : 2023-August-11
========================================================
"""
print_colored(banner, color_green)

try:
    # Reading the SQL file
    with open(sql_file_path, 'r') as sql_file:
        sql_statements = sql_file.read()

    # Splitting SQL statements by semicolon
    statements = sql_statements.split(';')

    # Executing each SQL statement
    cursor = connection.cursor()
    for idx, statement in enumerate(statements):
        statement = statement.strip()
        if statement:
            try:
                cursor.execute(statement)

                if statement.upper().startswith("SELECT"):
                    result = cursor.fetchall()
                    if result:
                        column_names = [desc[0] for desc in cursor.description]
                        column_headers = "Column Headers: " + ", ".join(column_names)
                        print_colored(column_headers, color_green)

                        for row in result:
                            print("Row:")
                            for col_name, col_value in zip(column_names, row):
                                print("{}: {}".format(col_name, col_value))
                            print("\n")

                    else:
                        print("No results.")

                    # Add a newline after the output of the first two SQL statements
                    if idx == 1:
                        print("\n")

                print("\n" * 2)  # Add a gap of two lines

            except Exception as e:
                print("Error executing statement:", statement)
                print("Error details:", str(e))

    connection.commit()
    print("SQL file execution completed.")

except Exception as e:
    connection.rollback()
    print("An error occurred:", str(e))

finally:
    if connection:
        connection.close()
