# app.py 
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
import uuid
import boto3
from botocore.exceptions import ClientError
import os

app = Flask(__name__, static_folder=".", static_url_path="")
CORS(app)

# Connect to DynamoDB
region = os.environ.get("AWS_REGION", "us-east-1")
dynamodb = boto3.resource("dynamodb", region_name=region)
table = dynamodb.Table("task-manager-data")

@app.route("/favicon.ico")
def favicon():
    return "", 204

@app.route("/")
def index():
    return send_from_directory(".", "index.html")

@app.route("/board", methods=["GET"])
def get_board():
    try:
        response = table.scan()
        items = response.get("Items", [])
        board = {}
        for task in items:
            col = task.get("column", "Uncategorized")
            if col not in board:
                board[col] = []
            board[col].append(task)
        return jsonify(board)
    except ClientError as e:
        return jsonify({"error": str(e)}), 500

@app.route("/columns", methods=["POST"])
def add_column():
    return jsonify({"message": "Columns are dynamic and handled client-side."}), 200

@app.route("/tasks", methods=["POST"])
def add_task():
    data = request.json
    column = data.get("column")
    title = data.get("title", "")
    description = data.get("description", "")
    status = data.get("status", "Not Started")
    if not column:
        return jsonify({"error": "Missing column"}), 400

    task_id = "DP-" + str(uuid.uuid4())[:8]
    task = {
        "task_id": task_id,
        "title": title,
        "description": description,
        "status": status,
        "column": column
    }

    try:
        table.put_item(Item=task)
        return jsonify(task), 201
    except ClientError as e:
        return jsonify({"error": str(e)}), 500

@app.route("/tasks/<task_id>", methods=["DELETE"])
def delete_task(task_id):
    try:
        table.delete_item(Key={"task_id": task_id})
        return jsonify({"message": "Task deleted."}), 200
    except ClientError as e:
        return jsonify({"error": str(e)}), 500

@app.route("/tasks/move", methods=["POST"])
def move_task():
    data = request.json
    task_id = data.get("id")
    to_col = data.get("to")
    new_status = data.get("status") 

    try:
        response = table.get_item(Key={"task_id": task_id})
        item = response.get("Item")
        if not item:
            return jsonify({"error": "Task not found."}), 404

        item["column"] = to_col
        if new_status:  
            item["status"] = new_status

        table.put_item(Item=item)
        return jsonify(item), 200
    except ClientError as e:
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=8080)
