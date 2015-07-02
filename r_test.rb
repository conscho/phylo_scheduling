require 'rinruby'

R.image_path = "sample1.png"

my_array1 = [1, 10, 3]
my_array2 = [1, 4, 2, 4, 3]
my_array3 = [1, 4, 2, 5, 3, 8, 5, 2, 4, 3]

R.numbers1 = my_array1
R.numbers2 = my_array2
R.numbers3 = my_array3
R.index1 = 1
R.index2 = 2
R.index3 = 3

R.eval <<EOF
dataList = list()
dataList = c(dataList, list(numbers1))
dataList = c(dataList, list(numbers2))
dataList = c(dataList, list(numbers3))

png(filename=image_path)
boxplot(dataList, main=toupper("Comparison of trees from one dataset"),
        xlab="Type of trees for the dataset", ylab="Ratio of computational savings")
dev.off()
EOF


R.eval <<EOF
       png(filename="sample2.png")
       data<-data.frame(
         Stat31=rnorm(10,mean=6,sd=0.5),
         Stat41=rnorm(20,mean=10,sd=0.5),
         Stat12=rnorm(100,mean=4,sd=2))
       boxplot(data)
       dev.off()
EOF
