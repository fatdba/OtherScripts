# ... (Previous code)

# Function to generate a CSV report (modified to handle empty results)
def generate_csv_report(data, csv_filename):
    if not data:
        # If data is empty, create an empty CSV report
        with open(csv_filename, 'w', newline='') as csvfile:
            writer = csv.writer(csvfile)
            writer.writerow(["No data available"])

    else:
        # If data is not empty, create a CSV report with the data
        with open(csv_filename, 'w', newline='') as csvfile:
            writer = csv.writer(csvfile)
            writer.writerow(data[0].keys())  # Write headers
            for row in data:
                writer.writerow(row.values())

# Function to generate a PDF report (modified to handle empty results)
def generate_pdf_report(data, pdf_filename):
    from fpdf import FPDF

    class PDF(FPDF):
        def header(self):
            self.set_font('Arial', 'B', 12)
            self.cell(0, 10, 'Database Report', 0, 1, 'C')

        def footer(self):
            self.set_y(-15)
            self.set_font('Arial', 'I', 8)
            self.cell(0, 10, f'Page {self.page_no()}', 0, 0, 'C')

    if not data:
        # If data is empty, create an empty PDF report
        pdf = PDF()
        pdf.add_page()
        pdf.set_font('Arial', '', 12)
        pdf.cell(0, 10, "No data available", 0, 1, 'C')
        pdf.output(pdf_filename)

    else:
        # If data is not empty, create a PDF report with the data
        pdf = PDF()
        pdf.add_page()
        pdf.set_font('Arial', '', 12)
        for row in data:
            for key, value in row.items():
                pdf.cell(70, 10, f'{key}:', 0)
                pdf.cell(0, 10, str(value), 0, 1)
        pdf.output(pdf_filename)

# ... (Rest of the code remains unchanged)

