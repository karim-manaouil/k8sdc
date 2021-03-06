import json
import os, sys
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
        #draw_histograms(pair, ys)

#
# returns (le, count)
# 
def get_reached_100p_rv(shdb, res, verb):
    maxx = shdb[res][verb]["70"]
    keys = shdb[res][verb].keys()
    
    formatN = lambda n: n if n%1 else int(n)
    okeys = [str(formatN(l)) for l in [k for k in sorted([float(j) for j in keys])]] # Ordered list of buckets

    for k in okeys:
            if shdb[res][verb][k] == maxx:
                return k, shdb[res][verb][k]
# 
# returns ordered map of [res/verb/count]=le
#
def get_reached_100p_ordered(shdb):
    uo = {}
    for res in shdb:
        for verb in shdb[res]:
            le, count = get_reached_100p_rv(shdb, res, verb)
            uo[res + "/" + verb] = le + "/" + count
    
    oo = {k: v for k, v in \
            sorted(uo.items(), key=lambda item: float(item[1].split("/")[0]))}
    
    return oo


def print_reached_100p_at(oo_list):
    ref = oo_list[0]
    
    for key in ref:
        concat = [] 
        concat.append(ref[key])
        
        for oo in oo_list[1:]:
            if key not in oo:
                concat.append("??/??")
            else:
                concat.append(oo[key])

        concat.insert(0, key)
        
        print("\n%-50s " % (concat[0]), end="")
        for i in range(1, len(concat)):
            print("%-10s " % (concat[i]), end="")
        
    print("")
        
# Histograms database parser.
# This generates a map of resources to (a map 
# of verbs to (a map of "le" to (values)))
def parse_hdb(path):
    shdb = {} # resources map
    
    with open(path, "r") as f:
        hdb = json.load(f)

        for o in hdb["data"]["result"]:
            if "resource" in o["metric"]:
                res = o["metric"]["resource"]
                verb = o["metric"]["verb"]
            else:
                res = "all"
                verb = "all"

            le  = o["metric"]["le"]
            
            if res not in shdb:
                shdb[res] = {}

            if verb not in shdb[res]:
                shdb[res][verb] = {}

            ln = len(o["values"])
            shdb[res][verb]["70" if le == "+Inf" else le] \
                    = o["values"][ln-1][1]  # Get the latest value

    #import pdb; pdb.set_trace()
    return shdb

def generate_cdf_from_hdb(shdb_list, res, verb):
    ys = []
    formatN = lambda n: n if n%1 else int(n)
    
    for entry in shdb_list:
        if res not in entry["shdb"] or \
                verb not in entry["shdb"][res]:
                    continue

        m = entry["shdb"][res][verb] # map[le]val                         
        T = float(m["70"]) # Total requests
        x = [str(formatN(l)) for l in [k for k in sorted([float(j) for j in m.keys()])]] # Ordered list of buckets
        y = [ float(m[k])/T*100 for k in x]

        ys.append({
            "latency": entry["latency"],
            "x": x,
            "y": y,
            "count": T
            })

    return ys

def draw_cdfs(pair, ys): 
    for y in ys:
        # making the graph look better
        for p in range(99, 70, -1):
            if p < y["y"][0]:
                y["y"].insert(0, p)
                y["x"].insert(0, y["x"][0])

        plt.plot(y["x"], y["y"], label = y["latency"] + "ms")

    plt.xticks(rotation=90)
    plt.xticks([0, 1, 5, 9, 12, 16, 20, 25, 30, 36])
    #plt.xlabel('Durations (s)')
    #plt.ylabel('Percentage')
    plt.title('request duration CDF of ' + pair[0] + " " + pair[1])
    
    plt.legend()
    plt.show()


def draw_2cdfs(pair, ya, yb): 
   
    params = {'xtick.labelsize':'x-small'}

    plt.rcParams.update(params)

    fig, (ax1, ax2) = plt.subplots(2, 1)
    fig.suptitle('Horizontally stacked subplots')
    for y in ya:
        for p in range(99, 70, -1):
            if p < y["y"][0]:
                y["y"].insert(0, p)
                y["x"].insert(0, y["x"][0])

        ax1.plot(y["x"], y["y"], label = y["latency"] + "ms")

    for y in yb:
        for p in range(99, 70, -1):
            if p < y["y"][0]:
                y["y"].insert(0, p)
                y["x"].insert(0, y["x"][0])

        ax2.plot(y["x"], y["y"], label = y["latency"] + "ms")
   

    plt.setp((ax1, ax2), xticks=[0, 1, 5, 9, 12, 16, 20, 25, 30, 36] )

    for ax in fig.axes:
        matplotlib.pyplot.sca(ax)
        plt.xticks(rotation=90)

    matplotlib.rcParams.update({'font.size': 8})
    
    #ax1.set_title("kubelets and kube-proxy requests")
    #ax2.set_title("master-based components requests")

    #plt.xlabel('Durations (s)')
    #plt.ylabel('Percentage')

    ax1.legend()
    plt.show()


def draw_cdf_from_hdb(shdb_list):
    alld = []
    for res in shdb_list[0]["shdb"]:
        for verb in shdb_list[0]["shdb"][res]:
            ys = generate_cdf_from_hdb(shdb_list, res, verb)
            alld.append({
                "resource": res,
                "verb": verb,
                "ys": ys
                })

    for d in alld:
        draw_cdfs([d["resource"], d["verb"]], d["ys"])

# selects the pairs that make select(shdb, res, verb)
# return true. 
def select_pairs_cond(shdb, arg, selector):
    selection = []
    for res in shdb:
        for verb in shdb[res]:
            buk, maxx = get_reached_100p_rv(shdb, res, verb)
            if selector(buk, arg):
                selection.append([res, verb, buk, maxx])

    return selection

def select_pairs_longer_than(shdb, time):
    def is_longer(a, b):
        r = True if (float(a) > float(b)) else False
        return r

    return \
            select_pairs_cond(shdb, time, is_longer)

def select_pairs_less_than(shdb, time):
    def is_less(a, b):
        r = True if (float(a) <= float(b)) else False
        return r

    return \
            select_pairs_cond(shdb, time, is_less)

def get_pairs_longer_than(shdb, bucket):
    pairs = []
    for res in shdb:
          for verb in shdb[res]:
              buk, maxx = get_reached_100p_rv(shdb, res, verb)
              v = shdb[res][verb][bucket]
              if float(maxx) > float(v):
                  pairs.append([res, verb, bucket, 
                      str(int(maxx) - int(v)), buk, maxx])

    return pairs

def print_pairs(pairs):
    pairs.sort(key=lambda s: float(s[3]))
    print("%-30s %-15s %-10s" % ("res/verb", "longer/total", "100%"))
    for s in pairs:
        print("%-30s %-15s %-10s" % (s[0]+"/"+s[1], s[3]+"/"+s[5], s[4]))

def print_selection(selection):
    selection.sort(key=lambda s: float(s[2]))
    print("%-30s %-10s %-10s" % ("res/verb", "buckt", "rq"))
    for s in selection:
        print("%-30s %-10s %-10s" % (s[0]+"/"+s[1], s[2], s[3]))

# ./tables.py CLIENT MODE={all|hdb} SW={0/table|1/cdf} [RESOURCE VERB]
def main():    
    #latencies = ["0", "50", "250", "400", "50l", "250l", "400l"]
    latencies = ["0", "50", "250", "400"]
    
    if len(sys.argv) < 3:
        print("missing argument")
        sys.exit(1)

    client = sys.argv[1]
    mode = "all" if sys.argv[2]=="all" else "hdb"
     
    shdb_list = [] 
    for lat in latencies:
        hdb_path = os.path.join("hdb", lat, client, mode + ".json")
        shdb_list.append({"latency": lat, 
                "shdb":parse_hdb(hdb_path)})

    shdb_list_2 = [] 
    for lat in latencies:
        hdb_path = os.path.join("hdb", lat, "master", mode + ".json")
        shdb_list_2.append({"latency": lat, 
                "shdb":parse_hdb(hdb_path)})


    # switch
    sw=sys.argv[3]
    if sw == "table": # mode=hdb => table
        oo_list = []
        for shdb in shdb_list:
            oo_list.append(
                    get_reached_100p_ordered(shdb["shdb"]))

        print_reached_100p_at(oo_list)

    elif sw == "cdf": # mode=hdb/all [res] [verb] => cdf
        res = "all" if mode=="all" else sys.argv[4]
        verb = "all" if mode=="all" else sys.argv[5]

        draw_2cdfs([sys.argv[1] + " " + res, verb], 
                generate_cdf_from_hdb(shdb_list, res, verb),
                generate_cdf_from_hdb(shdb_list_2,res,verb))

    elif sw == "longer" or sw == "less":# mode=hdb [latency] [time]
        ltoi={"0":0, "50":1, "250":2, "400":3, "1000":4}
        
        latency = sys.argv[4]
        time = sys.argv[5] 
        
        shdb = shdb_list[ltoi[latency]]["shdb"]
        
        if sw == "longer":
            s = get_pairs_longer_than(shdb, time)
            print_pairs(s)
        else:
            s = select_pairs_less_than(shdb, time)
            print_selection(s)        

main()
