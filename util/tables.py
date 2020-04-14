import json
import os
import copy 

import matplotlib
import matplotlib.pyplot as plt
import numpy as np

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

# This function assumes there is one resource and one verb.
# One should use a script and a filesystem key-value based
# hierarchy to organize its structure for structured parsing.
# This decouples responsability and makes things easier to 
# build.
# Assumes one verb and one resource only in the list
def get_cdf_of(resource, verb, path):
    filename = os.path.join(path, resource, verb + ".json")

    with open(filename, "r") as f:
        obj = json.load(f)
        result = obj["data"]["result"]
        result.sort(key=lambda k: float(k["metric"]["le"]))
        
        x = []
        y = []
        
        count = float(result[len(result) - 1]["value"][1])

        for o in result:
            x.append(o["metric"]["le"])
            y.append(float(o["value"][1])/count*100)

        return x, y, count

def draw_cdfs(pair, ys): 
    for y in ys:
        # making the graph look better
        for p in range(99, 70, -1):
            if p < y["y"][0]:
                y["y"].insert(0, p)
                y["x"].insert(0, y["x"][0])

        plt.plot(y["x"], y["y"], label = y["latency"] + "ms")
    
    plt.xlabel('Durations (s)')
    plt.ylabel('Percentage')
    plt.title('api request duration CDF of ' + pair[0] + " " + pair[1])

    import numpy as np
    
    #plt.xticks(np.arange(70, 100, 1)) 
    #plt.ylim([90, 100.5])

    # plt.yticks(np.arange(90, 100, 1))

    plt.legend()
    plt.show()
    
    #plt.savefig(pair[0] + "_" + pair[1] + ".png", dpi=1000)

def draw_histograms(pair, ys):
    x = np.arange(len(ys[0]["x"]))

    fig, ax = plt.subplots()
    
    i = 0; rs = []
    for y in ys:
        yp = copy.deepcopy(y)
        for i in range(0, len(yp)):
            yp[i] = yp[i]/100*y["count"]
        rs.append(ax.bar(x + 0.25*i, yp, width = 0.25, label = y["latency"] + "ms"))
        i = i + 1

    ax.set_xticks(x)
    ax.set_xticklabels(ys[0]["x"])
    ax.legend()

    fig.tight_layout()
    
    ax.set_xlabel("Frequency")
    ax.set_ylabel('Latency')
    ax.set_title(pair[0] + " " + pair[1] + " frequency histogram")

    plt.show()

def generate_cdfs(pairs, latencies, path):
    for pair in pairs:
        ys=[]
        for latency in latencies:
           p = os.path.join(path, latency + "ms")
           x, y, count = get_cdf_of(pair[0], pair[1], p)
           
           ys.append({
               "latency": latency,
               "x": x,
               "y": y,
               "count": count
               })

        draw_cdfs(pair, ys)
        draw_histograms(pair, ys)

def main():
    # create_stats(stats, types)
    # convert_stats_to_json(stats)

    # t = create_pod_stats("90")
    # r = convert_pod_stats_to_json(t)

    # with open("pods_90.json", "w+") as fh:
        # json.dump(r, fh)
   
    pairs = []
    pairs.append(["sum", "SUM"])
    pairs.append(["pods", "LIST"])    
    pairs.append(["pods", "PATCH"])
    pairs.append(["configmaps", "LIST"])
    
    latencies = ["0", "25", "50", "250", "400"]
    
    generate_cdfs(pairs, latencies, "cdf")

main()
