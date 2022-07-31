from flask import Flask, send_from_directory
from whitenoise import WhiteNoise

app = Flask(__name__)
app.wsgi_app = WhiteNoise(app.wsgi_app, root="public/", index_file=True)

@app.route("/test")
def main():
    return "1234"