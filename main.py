from flask import Flask, request, current_app,g,render_template
import shelve
import time
import json

app = Flask(__name__)
app.config['AVERAGE_COUNT'] = 20

def get_db():
    db = getattr(g, '_database', None)
    if db is None:
        db = g._database = shelve.open('beer_daemon.db')
    return db

def dist_to_beers(dist):
	dist = float(dist)
	if(dist > 45):
		return 0
	if(dist > 40):
		return 1
	if(dist > 35):
		return 2
	if(dist > 28):
		return 3
	if(dist > 21):
		return 4
	if(dist > 15):
		return 5
	if(dist > 10):
		return 6
	return 7

def average_temp(db):
	idx = int(db["idx"])
	avgCount = int(app.config['AVERAGE_COUNT'])
	if(idx >= avgCount):
		db["idx"] = 0
	average = 0.0;
	nonNullCount = 0;
	for x in range(0, avgCount):
		temp = db["temp" + str(x)]
		if(temp != None):
			nonNullCount+=1
			average = average + float(temp)

	average = average / nonNullCount
	return average


@app.teardown_appcontext
def teardown_db(exception):
    db = getattr(g, '_database', None)
    if db is not None:
        db.close()

@app.before_first_request
def setup_db():
	db = get_db()
	for x in range(0,app.config['AVERAGE_COUNT']):
		db["temp" + str(x)] = None
	db["idx"] = 0;

@app.route("/update_temp")
def update_temp():
	db = get_db()
	idx = int(db["idx"])
	db["temp" + str(idx)] = request.headers.get("temp")
	db["idx"] = idx + 1
	db["temp"] = average_temp(db)
	return ""

@app.route("/update_dist")
def update_dist():
	db = get_db()
	db["dist"] = request.headers.get("dist")
	return ""

@app.route("/poll")	
def poll():
	db = get_db()
	data = { "temp": "{:.1f}".format(db["temp"]), "beers": dist_to_beers(db["dist"]) }
	return json.dumps(data)

@app.route("/")	
def main():
	return render_template('index.html');
    

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=80, debug=True)