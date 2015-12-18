These scripts generate statistics and data distributions for a given number of CPUs for partitioned phylogenetic datasets. The scripts are programmed to be compatible with the output of RAxML (https://github.com/stamatak/standard-RAxML), but can also be used with other phylip + partition + tree combinations generated by other tools.

For details about the results and implications please refer to the preprint paper [scheduling.pdf](scheduling.pdf)

## How to use
The scripts are command line tools. Usage can be viewed via `COMMAND help`. For example `scheduling help` will print:
```
Commands:
  scheduling generate -b, --number-of-bins=N -l, --phylip-file=PHYLIP_FILE -p, --partition-file=PARTITION_FILE -t, --tree-file=TREE_FILE  # schedule partitions on bins considering subtree repeats for...
  scheduling help [COMMAND]                                                                                                               # Describe available commands or one specific command
```

To get more details for the `generate` command, enter `scheduling help generate`:

```
Usage:
  scheduling generate -b, --number-of-bins=N -l, --phylip-file=PHYLIP_FILE -p, --partition-file=PARTITION_FILE -t, --tree-file=TREE_FILE
Options:
  -t, --tree-file=TREE_FILE                # Which tree should be used. Example: '-t ./data/59/parsimony_trees/RAxML_result.T4.RUN.0' 
  -p, --partition-file=PARTITION_FILE      # Path to partition file. Example: '-p ./data/59/59.partitions' 
  -l, --phylip-file=PHYLIP_FILE            # Path to phylip file. Example: '-l ./data/59/59.phy' 
  -b, --number-of-bins=N                   # Number of bins that the sites should be distributed to. Example: '-b 3' 
  -g, [--groundtruth], [--no-groundtruth]  # Compare the heuristics with the groundtruth. If true the dataset will be cropped since the groundtruth can only handle a limited amount of sites. Example: '-g true' 
  -n, [--crop-partitions=N]                # Crop the datafile to x partitions. Example: '-n 3' 
                                           # Default: 2
  -s, [--crop-sites-per-partition=N]       # Crop the number of sites in each partition to x. Recommended maximum bins to total sites: 2-20 | 3-14 | 4-12. Example: '-s 7' 
                                           # Default: 5
```

The scripts will place the output as CSV in the corresponding `output` folder. It will also tell you which R script to run, to visualize this ouptut. The R scripts don't need any input, just hit run. They will place the generated graphs in the [graphs](graphs) folder.

## Requirements
- The scripts expect that number of sites > bins. For best results number of sites >> bins.
- Partitions have to have unique names, since we save them in a hash.
- The tree file has to be in the Newick format: https://en.wikipedia.org/wiki/Newick_format
- The phylip file has to be in the sequential format. The scripts will not work with the interleaved format.
- For the statistics we used RAxML to infer 100 trees per dataset. For this RAxML has been called with the following options: `./raxmlHPC-PTHREADS-SSE3 -m GTRGAMMA -p 123456 -s ./PHYLIP.phy -# 100 -q ./PARTITIONS.partitions -T 48 -n T1`. Since we also wanted to compare trees based on random vs trees based on parsimony starting trees, we also ran RAxML with the option `-d` for random starting trees.

## Example Data ###
- The 8 evaluated datasets can be found in the folder [data](data)
- The infered trees by RAxML can be found in the respective subfolders of the datasets.
- A sample output for each script can be found in the corresponding output folder. The sample graphs can be found in the folder [graphs](graphs).

## Description of each script ###
### scheduling:
Applies 72 heuristics for a given dataset and number of CPUs to optimize load balance across those CPUs when evaluating the Phylogenetic Likelihood Function.
Options: By using `-g true` it will compare the 72 heuristics with the groundtruth. That is the optimal solution by evaluating all possible distributions. Note that, by using this parameter the partitions will be cropped. The level of cropping can be defined by using `-n` and `-s`. There is also a random parameter to drop 0 up to 2 sites from each partition to make the scenario more realistic.
- Example Usage: `./scheduling generate -t ./data/59/parsimony_trees/RAxML_result.T4.RUN.0 -p ./data/59/59.partitions -l ./data/59/59.phy -b 16`
- Example CSV Output: [/output_scheduling/](/output_scheduling/)
- Example Graph Output: [/graphs/data-59 2015-12-17 15-47-45 scheduling.pdf](/graphs/data-59 2015-12-17 15-47-45 scheduling.pdf)

### optimal_solution:
Generates the groundtruth/optimal data distribution for the given dataset.
- Example Usage: `./optimal_solution generate -t ./data/10a/parsimony_trees/RAxML_result.T2.RUN.0 -p ./data/10a/10.partitions -l ./data/10a/10.phy -b 2 -n 3 -s 7`
- Example CSV Output: [/output_optimal_solution/](/output_optimal_solution/)
- Example Graph Output: [/graphs/data-10a 2015-12-18 11-32-12 optimal solution.pdf](/graphs/data-10a 2015-12-18 11-32-12 optimal solution.pdf)

### site_dependencies_count:
Compares the amount of SRCs of each site for different types of trees.
- Example Usage: `./site_dependencies_count generate -b pars:./data/128/parsimony_trees/*parsimonyTree* pars_ml:./data/128/parsimony_trees/*result* rand_ml:./data/128/random_trees/*result* -p ./data/128/128.partitions -l ./data/128/128.phy`
- Example CSV Output: [/output_site_dependencies_count/](/output_site_dependencies_count/)
- Example Graph Output: 
[site dependencies.pdf](/graphs/data-128 2015-12-18 11-24-38 site dependencies.pdf), 
[site dependency distribution for all trees.pdf](/graphs/data-128 2015-12-18 11-24-38 site dependency distribution for all trees.pdf), 
[site dependency distribution for one tree.pdf](/graphs/data-128 2015-12-18 11-24-38 site dependency distribution for one tree.pdf)

### site_dependencies_graph:
Visualizes the SRs and their dependencies between sites for each site. The dependency graph is force based, which means that sites that are close together have more dependencies than sites that are further apart.
- Example Usage: `./site_dependencies_graph generate -t ./data/59/parsimony_trees/RAxML_result.T4.RUN.0 -p ./data/59/59.partitions.uniq -l ./data/59/59.phy.uniq -r 20`
- Example CSV Output: [/output_site_dependencies_graph/](/output_site_dependencies_graph/)
- Example Graph Output: [site dependencies graph.pdf](/graphs/data-59 2015-12-18 11-21-37 site dependencies graph.pdf)

### sorting1:
Analyzes the effect of sorting sites lexicographically. 
- Example Usage: `./sorting1 generate -b pars_ml:./data/404/parsimony_trees/*result* rand_ml:./data/404/random_trees/*result* -p ./data/404/404.partitions -l ./data/404/404.phy`
- Example CSV Output: [/output_sorting1/](/output_sorting1/)
- Example Graph Output: [sorting1.pdf](/graphs/data-404 2015-11-15 15-15-13 sorting1.pdf)
- Example Summary for Multiple Calls: [sorting1 summary.pdf](/graphs/sorting1 summary.pdf)

### sorting2:
Analyzes the effect of sorting sites lexicographically and compares it to a Minimal Spanning Tree approach of sorting sites. 
- Example Usage: `./sorting2 generate -t ./data/59/parsimony_trees/RAxML_result.T4.RUN.0 -p ./data/59/59.partitions -l ./data/59/59.phy`
- Example CSV Output: [/output_sorting2/](/output_sorting2/)
- Example Graph Output: [sorting2.pdf](/graphs/data-59 2015-12-18 11-17-54 sorting2.pdf)

### sorting3:
Analyzes the effect of sorting sites lexicographically for the RAxML trace. 
- Example Usage: `./sorting3 generate -T ./data/trace/101.trace.topo -l ./data/trace/101.phy -p ./data/trace/101.partitions`
- Example CSV Output: [/output_sorting3/](/output_sorting3/)
- Example Graph Output: [sorting3.pdf](/graphs/data-trace 2015-11-16 23-15-22 sorting3.pdf)

### statistics:
Calculates the potential savings due to the SR optimization in the Phylogenetic Likelihood Function for our datasets.
- Example Usage: `./statistics generate -b pars:./data/128/parsimony_trees/*parsimonyTree* pars_ml:./data/128/parsimony_trees/*result* rand_ml:./data/128/random_trees/*result* -p ./data/128/128.partitions -l ./data/128/128.phy -t all`
- Example CSV Output: [/output_statistics/](/output_statistics/)
- Example Graph Output:
[height to savings.pdf](/graphs/data-128 2015-12-18 12-31-06 height to savings.pdf),
[likelihood to savings.pdf](/graphs/data-128 2015-12-18 12-31-06 likelihood to savings.pdf),
[savings per batch.pdf](/graphs/data-128 2015-12-18 12-31-06 savings per batch.pdf),
[savings per partition.pdf](/graphs/data-128 2015-12-18 12-31-06 savings per partition.pdf),
[split loss comparison per partition.pdf](/graphs/data-128 2015-12-18 12-31-06 split loss comparison per partition.pdf),
[split loss per partition.pdf](/graphs/data-128 2015-12-18 12-31-06 split loss per partition.pdf),
[splitt loss per batch.pdf](/graphs/data-128 2015-12-18 12-31-06 splitt loss per batch.pdf)

### taxa_site_analysis:
Analyzes whether the number of sites and/or the number of taxa have an impact on the savings due to the SR optimization.
- Example Usage: `./taxa_site_analysis generate -t ./data/59/parsimony_trees/RAxML_result.T4.RUN.0 -p ./data/59/59.partitions.uniq -l ./data/59/59.phy.uniq`
- Example CSV Output: [/output_taxa_site_analysis/](/output_taxa_site_analysis/)
- Example Graph Output: 
[variation taxa site.pdf](/graphs/data-59 2015-12-18 11-09-47 variation taxa site.pdf),
[variation taxa.pdf](/graphs/data-59 2015-12-18 11-09-47 variation taxa.pdf),
[variation sites.pdf](/graphs/data-59 2015-12-18 11-09-47 variation sites.pdf)


## Credits
Thanks to Jonathan Badger and his Newick-Ruby routines: https://github.com/jhbadger/Newick-ruby