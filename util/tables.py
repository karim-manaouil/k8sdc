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
    create_stats(stats, types)
    convert_stats_to_json(stats)

main()
