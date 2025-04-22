# imports
from flask import Flask, request, jsonify
from flask_cors import CORS
import uuid
import boto3

app = Flask(__name__)
CORS(app)  # allow frontend to talk to backend

# Connect to DynamoDB
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')  # change region if needed
table = dynamodb.Table('Tasks')

# test list
tasks = []

@app.route("/tasks", methods=["GET"])
def get_tasks():
    return jsonify(tasks), 200

@app.route("/tasks", methods=["POST"])
def add_task():
    data = request.json
    task_id = str(uuid.uuid4())
    task = {"id": task_id, "title": data.get("title", "")}
    tasks.append(task)
    return jsonify(task), 201

@app.route("/tasks/<task_id>", methods=["DELETE"])
def delete_task(task_id):
    global tasks
    tasks = [task for task in tasks if task["id"] != task_id]
    return jsonify({"message": "Task deleted"}), 200

if __name__ == "__main__":
    app.run(debug=True)
