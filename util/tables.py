import json
import os
import copy 

stats=[]
types= [["pods", "LIST"], ["pods", "POST"], ["configmaps", "GET"]]

def create_stats(stables, types):
    for t in types:
        table = create_stats_for(t[0], t[1])
        stats.append({
            "resource": t[0],
            "verb": t[1],
            "table": table
            })

def create_stats_for(resource, verb):
    rows=[]
    latencies=["0", "50", "250", "400"]

    for latency in latencies:
        cols = get_stats_of(resource, verb, latency)
        obj = { "latency": latency,
                "data": cols }
        rows.append(obj)

    return rows

def get_stats_of(resource, verb, latency):
    stat_cols=[]
    percentiles=["10", "20", "30", "40", "50", "60", \
            "70", "80", "90", "95", "99"]

    for percn in percentiles:
        filename = latency\
                .__add__("ms")\
                .__add__("_percn_")\
                .__add__(percn)\
                .__add__(".json")
        path = os.path.join("out", filename)

        with open(path) as jf:
            obj = json.load(jf)
            value = find_value_of(obj, resource, verb)

            stat_cols.append({
                "percentile": percn,
                "value": value
                })

    return stat_cols

def find_value_of(obj, resource, verb):
    for slot in obj["data"]["result"]:
        if slot["metric"]["resource"] == resource and \
                slot["metric"]["verb"] == verb:
                    return slot["value"][1]

def find_pod_step(obj, step, percn):
    for entry in obj["dataItems"]:
        if entry["labels"]["Metric"] == step:
            key = "Perc" + percn
            return entry["data"][key]

def get_pod_cols(obj, order, percn):
    cols = []
    for step in order:
        value = find_pod_step(obj, step, percn)
        cols.append({
            "phase": step,
            "value": value
            })

    return cols


def create_pod_stats(percn):
    order = ["create_to_schedule", "schedule_to_run", "run_to_watch", "pod_startup"]
    latencies = ["0", "50", "250", "400"]
    
    rows = []
    for latency in latencies:
        filename = latency.__add__(".json")
        filename = os.path.join("pods", filename)
        with open(filename, "r") as fh:
            obj = json.load(fh)
            cols = get_pod_cols(obj, order, percn)

        rows.append({
            "latency": latency,
            "cols": cols
            })

    return rows 

def convert_pod_stats_to_json(rows):
    table = []
    for row in rows:
        jobject = {}
        jobject["field"] = row["latency"]
        for col in row["cols"]:
            jobject[col["phase"]] = col["value"]
        table.append(jobject)
    return table

# Later the json obained can easily be converted to xls
# and exported to Excel for easy graphing
def convert_stat_to_json(stat):
    table = []; jobject = {}
    otable = stat["table"]
    for row in otable:
        jobject["field1"] = row["latency"] + "ms"
        i = 2
        for percn in row["data"]:
            key = percn["percentile"] + "%"
            jobject[key] = percn["value"]
            i = i + 1

        table.append(copy.deepcopy(jobject))
    
    return table

def convert_stats_to_json(stats):
    for stat in stats:
        table = convert_stat_to_json(stat)
        out = stat["verb"] + "_" + stat["resource"] + ".json"
        with open(out, "w+") as fh:
            json.dump(table, fh)
    
def main():
    # create_stats(stats, types)
    # convert_stats_to_json(stats)

    t = create_pod_stats("90")
    r = convert_pod_stats_to_json(t)

    with open("pods_90.json", "w+") as fh:
        json.dump(r, fh)

main()
