require 'rinruby'

my_array = [3, 5, 2, 3, 6, 7, 4, 5, 6, 2]

R.image_path = "sample2.png"
R.image_path2 = "sample3.png"
R.numbers = my_array

R.eval("png(filename=image_path)")
R.eval("boxplot(numbers, main='Number Array')")
R.eval("dev.off()")

R.eval <<EOF
     png(filename="image_path2.png")
     data<-data.frame(Stat11=numbers,
      Stat21=numbers,
      Stat31=rnorm(100,mean=6,sd=0.5),
      Stat41=rnorm(100,mean=10,sd=0.5),
      Stat12=rnorm(100,mean=4,sd=2))
     boxplot(data)
    dev.off()
EOF
