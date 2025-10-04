from jaseci.actions.live_actions import jaseci_action
#from intasend import APIService #Mpesa
#from twilio.rest import Client #whatsapp
import pandas as pd
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas
import os

@jaseci_action()
def generate_pdf(transactions:dict,filename:str="output.pdf"):
    """
    Generate a PDF report from the transaction data.
    """
    # Create a Pandas DataFrame from the transaction data
    df = pd.DataFrame(transactions)

    # Create a PDF document
    c = canvas.Canvas(filename, pagesize=A4)
    width, height = A4

    # Draw the table headers
    c.drawString(100, height - 100, "Mshauri Transaction Report")
    c.drawString(100, height - 120, "Date")
    c.drawString(200, height - 120, "Description")
    c.drawString(300, height - 120, "Amount")

    # Draw the table rows
    y = height - 140
    for index, row in df.iterrows():
        c.drawString(100, y, row["date"])
        c.drawString(200, y, row["description"])
        c.drawString(300, y, str(row["amount"]))
        y -= 20

    # Save the PDF document
    c.save()
    return {"status": "success", "message": "PDF generated successfully", "filename": filename}
#Excel report(premium feature)
@jaseci_action()
def generate_excel(transactions:dict,filename:str="output.xlsx"):
    """
    Generate an Excel report from the transaction data.
    """
    # Create a Pandas DataFrame from the transaction data
    df = pd.DataFrame(transactions)

    # Save the DataFrame to an Excel file
    df.to_excel(filename, index=False)
    return {"status": "success", "message": "Excel file generated successfully", "filename": filename}