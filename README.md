# PhenoJl
A Julia package implemening the sepsis phenotypes defined in:  

> Guirgis, F. W., Black, L. P., Henson, M., Labilloy, G., Smotherman, C., Hopson, C., Tfirn, I., DeVos, E. L., Leeuwenburgh, C., Moldawer, L., Datta, S., Brusko, T. M., Hester, A., Bertrand, A., Grijalva, V., Arango-Esterhay, A., Moore, F. A., & Reddy, S. T. (2021). A hypolipoprotein sepsis phenotype indicates reduced lipoprotein antioxidant capacity, increased endothelial dysfunction and organ failure, and worse clinical outcomes. Critical care (London, England), 25(1), 341. https://doi.org/10.1186/s13054-021-03757-5

The `NORMO` and `HYPO` phenotypes are established using hierarchical clustering of 15 features. Those features are:
| Feature | 
|---------|
| HDL           | 
| APOA1         | 
| total_SOFA    | 
| total_cholesterol | 
| ICAM1         | 
| LDL           | 
| SOFA_cardio   |
| SOFA_liver    |
| PON           | 
| SOFA_neuro    |
| temperature   | Celsius
| respiration_score | 
| SOFA_renal    | 
| sys_bp        | 
| SOFA_coag |

Notes:
* SOFA scores (excluding total_SOFA) range from 0 to 4.
* _temperature_ should be in Fahrenheit

## Docker image: labillgp/phenojl
The easiest way to run the package is to use the available Docker image. You can get Docker [here](https://docs.docker.com/get-docker/).  
Assuming `data.csv` contains at least 15 columns with the features names listed above, one can run:

```bash
> cd my_data_directory
> docker run --rm -v .:/fixtures labillgp/phenojl PhenoJl /fixtures/data.csv
```
If the docker image is not present on your system, it will be automatically downloaded from DockerHub.  

Arguments can be passed to the docker instance in a similar way as they are passed to the Julia package.  For instance, to map the features to column names (more details below), one can use:

```bash
> cd my_data_directory
> docker run --rm -v .:/fixtures labillgp/phenojl PhenoJl /fixtures/data.csv --configfile data.yml
```
The Julia repository contains an example of script using Docker for *nix systems.

## Julia package 

### Installation
The Julia programming language is trivial to install.  See the [official documentation](https://julialang.org/downloads/).  
To install `PhenoJl`, launch Julia and use:

```julia
using Pkg
Pkg.add("https://github.com/labilloyg/PhenoJl.git#0.1.0-rc1")
```
Tests are available and can be run using the `test` command in the Pkg REPL.

### Usage
The code below will create a file named `mydataset_phenotyped.csv` with the content of the datatset annotated with two new columns:  
* _cluster_: Either `1` or `2`, defining the clusters  
* _phenotype_: Either `HYPO` or `NORMO`, associating cluster to phenotype  

```julia
using PhenoJl
phenotype("mydataset.csv")
```

### Phenotype identification
The original publication reviews the patients clusters and associates a cluster to a phenotype. This package automatically identifies the phenotypes. To do so, it looks at the cholesterol levels. The cluster with the lowest average cholesterol level will be associated to `HYPO`. If the average value of either or both of HDL or HDL in `HYPO` cluster is higher than those in `NORMO`, a warning will be emitted.

### Input file format
The input file should be a csv file containing at least the 15 features. 
- More columns can be present in the dataset, they will be ignored by the algorithm and present in the phenotyped file. 
- If either a column named _cluster_ or _phenotype_ is present in the dataset, it will be discarded and replaced by the output of the algorithm.
- The column names should match the names of the features listed above or a configuration file (see below) should be provided to map features to columns. The output file will contain the original column names. 

### Configuration file
If the columns names of the input dataset do not match the names of the features, one can either rename the columns or provide a configuration file in YAML format such as:

```yaml
# config.yml
signature_to_column_mapping:
  LDL: A
  HDL: B
  total_cholesterol: C
```

It is not necessary to add all the features. Only the non-matching names are sufficient.  
Then use:
```julia
phenotype("mydataset.csv"; configfile="config.yml")
```

**Note**: The configuration file also allows a _features_ parameters defining the names of the columns to be taken into account by the algorithm. This option is useful for developement purpose.  

## Author
This package was written by [G. Labilloy](guillaume.labilloy@jax.ufl.edu).
