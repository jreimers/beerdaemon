from flask import Flask, request, current_app,g,render_template
import shelve
import time
import json

app = Flask(__name__)

def get_db():
    db = getattr(g, '_database', None)
    if db is None:
        db = g._database = shelve.open('beer_daemon.db')
    return db

@app.teardown_appcontext
def teardown_db(exception):
    db = getattr(g, '_database', None)
    if db is not None:
        db.close()

@app.route("/update")
def update():
	db = get_db()
	db["temp"] = request.headers.get("temp")
	db["dist"] = request.headers.get("dist")
	return ""

@app.route("/poll")	
def poll():
	db = get_db()
	data = { "temp": db["temp"], "dist": db["dist"] }
	return json.dumps(data)

@app.route("/")	
def main():
	return render_template('index.html');
    

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=80, debug=True)