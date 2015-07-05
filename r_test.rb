require 'rinruby'

R.image_path = "graphs/sample1.png"

my_array1 = [1, 10, 3]
my_array2 = [1, 4, 2, 4, 3]
my_array3 = [1, 4, 2, 5, 3, 8, 5, 2, 4, 3]
my_names = ["pars", "pars_ml", "rand_ml"]

R.numbers1 = my_array1
R.numbers2 = my_array2
R.numbers3 = my_array3
R.arrnames = my_names

R.eval <<EOF
dataList = list()
dataList = c(dataList, list(numbers1))
dataList = c(dataList, list(numbers2))
dataList = c(dataList, list(numbers3))

names(dataList) <- arrnames

png(filename=image_path)
boxplot(dataList, main=toupper("Comparison of trees from one dataset"),
        xlab="Type of trees for the dataset", ylab="Ratio of computational savings",
        par(mar = c(12, 5, 4, 2) + 0.1))
mtext("Test", side=1, line=5)
dev.off()
EOF


R.eval <<EOF
       png(filename="graphs/sample2.png")
       data<-data.frame(
         Stat31=rnorm(10,mean=6,sd=0.5),
         Stat41=rnorm(20,mean=10,sd=0.5),
         Stat12=rnorm(100,mean=4,sd=2))
       boxplot(data)
       dev.off()
EOF
