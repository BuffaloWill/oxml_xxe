from flask import Flask, render_template, request
import docx

app = Flask(__name__)

@app.route('/', methods=['GET', 'POST'])
def upload_file():
    if request.method == 'POST':
        file = request.files['file']
        if file:
            document = docx.Document(file)
            main_content = '\n\n'.join([paragraph.text for paragraph in document.paragraphs])
            # Print the main content to the console
            return 'File uploaded and parsed successfully!' + "\n"+main_content
    return render_template('upload.html')

if __name__ == '__main__':
    app.run(host='0.0.0.0')