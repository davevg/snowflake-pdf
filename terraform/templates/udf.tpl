from PyPDF2 import PdfFileReader
from snowflake.snowpark.files import SnowflakeFile
from io import BytesIO
def read_file(file_path):
    whole_text = ""
    with SnowflakeFile.open(file_path, 'rb') as file:
        f = BytesIO(file.readall())
        pdf_reader = PdfFileReader(f)
        whole_text = ""
        for page in pdf_reader.pages:
            whole_text += page.extract_text()
    return whole_text