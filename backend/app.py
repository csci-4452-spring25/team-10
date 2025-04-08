# imports
from flask import Flask
from flask_cors import CORS

app = Flask(__name__)
CORS(app)  # allow frontend to talk to backend

# test list
tasks = []

if __name__ == "__main__":
    app.run(debug=True)
