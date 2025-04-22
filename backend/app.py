# imports
from flask import Flask, request, jsonify
from flask_cors import CORS
import uuid
import boto3
from boto3.dynamodb.conditions import Key

app = Flask(__name__)
CORS(app)  # allow frontend to talk to backend

# connect to DynamoDB (for vinh)
dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
table = dynamodb.Table("task_manager_data")

# test list
tasks = []

# board and column
@app.route("/board", methods=["GET"])
def get_board():
    board = {}
    columns_resp = table.query(
        KeyConditionExpression=Key("pk").eq("COLUMN")
    )
    columns = [item["sk"] for item in columns_resp.get("Items", [])]

    for col in columns:
        tasks_resp = table.query(
            KeyConditionExpression=Key("pk").eq(f"TASK#{col}")
        )
        board[col] = tasks_resp.get("Items", [])
    return jsonify(board), 200

@app.route("/columns", methods=["POST"])
def add_column():
    data = request.json
    name = data.get("name", "").strip()
    if not name:
        return jsonify({"error": "Column name required."}), 400

    table.put_item(Item={"pk": "COLUMN", "sk": name})
    return jsonify({"message": f"Column '{name}' added."}), 201

# task methods
@app.route("/tasks", methods=["POST"])
def add_task():
    data = request.json
    column = data.get("column")
    title = data.get("title", "")
    description = data.get("description", "")
    status = data.get("status", "Not Started")

    if not column:
        return jsonify({"error": "Column is required"}), 400

    task_id = "DP-" + str(uuid.uuid4())[:8]
    task = {
        "pk": f"TASK#{column}",
        "sk": task_id,
        "id": task_id,
        "title": title,
        "description": description,
        "status": status
    }

    table.put_item(Item=task)
    return jsonify(task), 201

@app.route("/tasks/<task_id>", methods=["DELETE"])
def delete_task(task_id):
    # search all columns to find the task
    columns = table.query(KeyConditionExpression=Key("pk").eq("COLUMN"))["Items"]
    for col in columns:
        col_name = col["sk"]
        resp = table.query(KeyConditionExpression=Key("pk").eq(f"TASK#{col_name}"))
        for task in resp["Items"]:
            if task["id"] == task_id:
                table.delete_item(Key={"pk": f"TASK#{col_name}", "sk": task_id})
                return jsonify({"message": "Task deleted."}), 200
    return jsonify({"error": "Task not found"}), 404

if __name__ == "__main__":
    app.run(debug=True)
