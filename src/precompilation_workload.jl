using Downloads
using PhenoJl

cluster_csv = "cluster.csv"
cluster_csv_conf = "cluster.csv.conf"
path = tempname(".")
mkdir(path)
cd(path)

Downloads.download("https://raw.githubusercontent.com/labilloyg/PhenoJl/master/fixtures/cluster.csv", joinpath(".", cluster_csv))
Downloads.download("https://raw.githubusercontent.com/labilloyg/PhenoJl/master/fixtures/cluster.csv.yml", joinpath(".", cluster_csv_conf))

ds = phenotype(cluster_csv; configfile=cluster_csv_conf, write_output=1)
ds = phenotype(cluster_csv; configfile=cluster_csv_conf, write_output=0)

cd("..")
rm(path; recursive=true)


