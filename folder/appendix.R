


```{r}
library(Rcpp)
library(dplyr)
library(ggplot2)
library(readxl)
data <- read_excel("data.xlsx", col_types = c("skip","skip", "skip", "skip", "numeric"))
data=ts(data,start = 1970, frequency = 4)

library(forecast)
autoplot(data, colour = 'black',main="TS Plot of ESB Connections")
```

```{r}
ggAcf(data,main="ACF of Data Set")
ggPacf(data,main="PACF of Data Set")
```

```{r}
library(tsutils)
data.dc <- decomp(data, outplot=1) 
residout(data.dc$irregular)
```

#Divide data into test and train set
```{r}
train <- window(data, start=1970, end=c(2015,4), frequency=4) 
test <- window(data, start=2016, frequency=4) 

autoplot(train) + autolayer(test)
```
#Box-Cox Transformation 
```{r}
library(TSA)
lambda=BoxCox.lambda(data)  #Since the lambda value is different than 1, we can say that the transformation is needed.
lambda
train_bc=BoxCox(train,lambda)
```
#anomaly detection 
```{r}
library(chron)
time=as.chron(train_bc)
time1=as.Date(time,format="%d-%b-%y")          #format is important.
train_bc_anomaly=data.frame(train_bc)
rownames(train_bc_anomaly)=time1            #Then, add time1 object as row names to data frame created for anomaly detection.
library(anomalize)                                                 #tidy anomaly detection
library(tidyverse) #tidyverse packages like dplyr, ggplot, tidyr
train_bc_anomaly_ts <- train_bc_anomaly %>% rownames_to_column() %>% mutate(date = as.Date(rowname)) %>% select(-one_of('rowname'))
train_bc_anomaly_ts <- train_bc_anomaly_ts %>% tibbletime::as_tbl_time(index = date)
train_bc_anomaly_ts %>% time_decompose(Total, method = "stl", frequency = "auto", trend = "auto") %>% anomalize(remainder, method = "gesd", alpha = 0.05, max_anoms = 0.2) %>%  plot_anomaly_decomposition()

train_bc_anomaly_ts %>% 
  time_decompose(Total) %>%
  anomalize(remainder) %>%
  time_recompose() %>%
  plot_anomalies(time_recomposed = TRUE, ncol = 3, alpha_dots = 0.5)
# New function that cleans & repairs anomalies
traindata_bc_clean<-tsclean(train_bc_anomaly_ts$Total)  
traindata_bc_clean<-ts(traindata_bc_clean,start = 1970, frequency = 4)
autoplot(traindata_bc_clean)+autolayer(train_bc,color="red")+theme_minimal()
```
##Differencing method to make process stationary
#Hegy test
```{r}
traindata_bc_clean<-tsclean(train_bc_anomaly_ts$Total)  
traindata_bc_clean<-ts(traindata_bc_clean,start = 1970, frequency = 4)
library(pdR)
test<-HEGY.test(traindata_bc_clean, itsd=c(1,0,c(1:3)))         #we need to take regular differencing.
test$stats
ndiffs(traindata_bc_clean)                                                       #One difference is required to pass the stationarity tests.
##canova hansen test 
library(uroot)
ch.test(traindata_bc_clean)
nsdiffs(traindata_bc_clean, test="ch")                                     #one seasonal difference
traindata_bc_clean_diff<-diff(traindata_bc_clean_diff, lag = 4, differences = 1) #regular and seasonal difference
test<-HEGY.test(traindata_bc_clean_diff, itsd=c(0,0,0))     #we have no unit root problem but ACF shows a non stationary problem.      
test$stats
nsdiffs(traindata_bc_clean_diff, test="ch", differences = 1)    #we have no unit root problem 
nsdiffs(diff(traindata_bc_clean_diff, lag = 4, differences = 1))  
autoplot(traindata_bc_clean_diff,main="TS Plot of Differenced Data")+theme_minimal()  #one regular and seasonal difference
```
##Model Suggestions
###ACF and PACF
```{r}
library(gridExtra)
library(grid)
p1<-ggAcf(traindata_bc_clean_diff,main="ACF of Differenced Series")
p2<-ggPacf(traindata_bc_clean_diff,main="PACF of Differenced Series")
grid.arrange(p1,p2,ncol=2)
```
##Identifying proper SARIMA model
```{r}
fit1<-Arima(traindata_bc_clean,order = c(0,1,1), seasonal = list(order=c(2,1,1), period=4), 
            method="ML") 
summary(fit1)
```
```{r}
fit2<-auto.arima(traindata_bc_clean,d=1,D=1, method = "ML")
summary(fit2)                                                                                       #best model
```
```{r}
fit3<-Arima(traindata_bc_clean,order = c(0,1,1), seasonal = list(order=c(1,1,1), period=4), 
            method="ML") 
summary(fit3)
```
##Diagnostic Check
```{r}
r=resid(fit2)                                                             #residuals function to extract residuals of the object.
autoplot(r)+geom_line(y=0)+theme_minimal()+ggtitle("Plot of The Residuals")
ggAcf(traindata_bc_clean_diff,lag=48)+theme_minimal()+ggtitle("ACF of Stat. Series")
ggPacf(traindata_bc_clean_diff,lag=48)+theme_minimal()+ggtitle("PACF of Stat. Series")
```

```{r}
p1=ggplot(r, aes(sample = r)) +stat_qq()+geom_qq_line()+ggtitle("QQ Plot of the Residuals")+theme_minimal()
p2=ggplot(r,aes(x=r))+geom_histogram(bins=20)+geom_density()+ggtitle("Histogram of Residuals")+theme_minimal()
p3=ggplot(r,aes(y=r,x=as.factor(1)))+geom_boxplot()+ggtitle("Box Plot of Residuals")+theme_minimal()
grid.arrange(p1,p2,p3,ncol=3)
```
```{r}
library(tseries)
shapiro.test(r)

```
#Box-Cox Transformation 
```{r}
library(TSA)
lambda=BoxCox.lambda(r)  #Since the lambda value is almost equal to 1, we can say that the transformation is not needed.
lambda
```

```{r}
library(TSA)
Box.test(r,type="Ljung",lag=20)                                                  # Portmanteau test for the null hypothesis of independence in a given time series.
library(lmtest)
bgtest(m,order=15) #order is up to you
p1=ggAcf(as.vector(r),main="ACF of the Residuals",lag = 48)+theme_minimal()      #to see time lags, as. factor function is used.
p2=ggPacf(as.vector(r),main="PACF of the Residuals",lag = 48)+theme_minimal()    #to see time lags, as. factor function is used.
grid.arrange(p1,p2,ncol=2)
```

# homoscedasticity check
```{r}
rr=r^2
g1<-ggAcf(as.vector(rr))+theme_minimal()+ggtitle("ACF of Squared Residuals")
g2<-ggPacf(as.vector(rr))+theme_minimal()+ggtitle("PACF of Squared Residuals") 
grid.arrange(g1,g2,ncol=2)
```

```{r}
library(aTSA)
arch.test(arima(traindata_bc_clean,order = c(1,1,3), seasonal = list(order=c(0,1,1), period=4), 
                method="ML"),output=TRUE)

```

##sarima
```{r}
train <- window(data, start=1970, end=c(2015,4), frequency=4)
test <- window(data, start=2016, frequency=4) 
forecast<-forecast::forecast(fit2,h=4)
accuracy(forecast,test)
##Back-Transformation
lambda<-BoxCox.lambda(train)
f_t<-InvBoxCox(forecast$mean,lambda,biasadj=TRUE,fvar = ((BoxCox(forecast$upper,lambda)-BoxCox(forecast$lower,lambda))/qnorm(0.975)/2)^2)
f_u<-InvBoxCox(forecast$upper,lambda)                          #back-transformation of forecast upper
f_l<-InvBoxCox(forecast$lower,lambda)                           #back-transformation of forecast lower
f_tr<-InvBoxCox(fitted(forecast),lambda)                         #back-transformation of fitted forecast values

accuracy(f_t,test)
computeMASE <- function(forecast,train,test,period){
  forecast <- as.vector(forecast)
  train <- as.vector(train)
  test <- as.vector(test)
  
  n <- length(train)
  scalingFactor <- sum(abs(train[(period+1):n] - train[1:(n-period)])) / (n-period)
  
  et <- abs(test-forecast)
  qt <- et/scalingFactor
  meanMASE <- mean(qt)
  return(meanMASE)
}
computeMASE(f_t,train,test,4)                                  ##MASE function

##normality test
r<-resid(fit2)
shapiro.test(r)

```

##ets
```{r}
library(forecast)
fr1<-ets(train,model="ZZZ")
autoplot(fr1)+theme_minimal()
##Holt-Winter’s
fr1<-forecast::forecast(fr1,h=4) #h represents the forecast horizons.
fr1
fr2=ets(train,model='MMM')
fr2<-forecast::forecast(fr2,h=4)
autoplot(train)+autolayer(fr1,PI=F,series="ETS(MAM)")+autolayer(fr2,PI=F,series="ETS(MMM)")+ggtitle("Forecasts from Different ETS")+theme_minimal()
accuracy(fr1,test)
accuracy(fr2,test)   #At the end, we can say that the best forecasting method ETS(MMM) according to MASE and MAPE criteria.
summary(fr2)

library(BootPR)
##normality test
r<-resid(fr2)
shapiro.test(r)
```

##prophet
```{r}
library(prophet)
ds<-c(seq(as.Date("1970/01/01"),as.Date("2015/10/01"),by="quarter"))
head(ds)
df<-data.frame(ds,y=as.numeric(train))
head(df)


train_prophet <- prophet(df,seasonality.mode = 'additive',yearly.seasonality = FALSE,weekly.seasonality = TRUE,daily.seasonality = TRUE)
future<-make_future_dataframe(train_prophet,periods =4,freq = "quarter", include_history = TRUE)
forecast <- predict(train_prophet, future)
accuracy(tail(forecast$yhat,4),test)
train_prophet <- prophet(df,seasonality.mode = 'additive',yearly.seasonality = TRUE,weekly.seasonality = FALSE,daily.seasonality = TRUE)
future<-make_future_dataframe(train_prophet,periods =4,freq = "quarter", include_history = TRUE)
forecast <- predict(train_prophet, future)
accuracy(tail(forecast$yhat,4),test)
train_prophet <- prophet(df,seasonality.mode = 'additive',yearly.seasonality = TRUE,weekly.seasonality = FALSE,daily.seasonality = FALSE)
future<-make_future_dataframe(train_prophet,periods =4,freq = "quarter", include_history = TRUE)
forecast <- predict(train_prophet, future)
accuracy(tail(forecast$yhat,4),test)
train_prophet <- prophet(df,seasonality.mode = 'multiplicative',yearly.seasonality = TRUE,weekly.seasonality = TRUE,daily.seasonality = TRUE)
future<-make_future_dataframe(train_prophet,periods =4,freq = "quarter", include_history = TRUE)
forecast <- predict(train_prophet, future)
accuracy(tail(forecast$yhat,4),test)
train_prophet <- prophet(df,seasonality.mode = 'additive',yearly.seasonality = TRUE,weekly.seasonality = TRUE,daily.seasonality = TRUE)                  #best model

future<-make_future_dataframe(train_prophet,periods =4,freq = "quarter", include_history = TRUE)
forecast <- predict(train_prophet, future)
forecast_t<-tail(forecast[c('ds', 'yhat', 'yhat_lower', 'yhat_upper')],4)        #test forecast
fore<-forecast[1:184,22]                                                                             #train forecast
fore=ts(fore,start = 1970, frequency = 4)                                                    #time series version of train forecast
accuracy(tail(forecast$yhat,4),test)
accuracy(head(forecast$yhat,184),train)
computeMASE(tail(forecast$yhat,4),train,test,4)                                       #MASE function
computeMASE(head(forecast$yhat,184),train,train,4)

##normality test
residuals_prophet = forecast[,22]-data
shapiro.test(residuals_prophet)

```

#tbats
```{r}
tbatsmodel<-tbats(train)
tbatsmodel
autoplot(train,main="TS plot of Train with TBATS Fitted") +autolayer(fitted(tbatsmodel), series="Fitted") +theme_minimal()
tbats_forecast<-forecast::forecast(tbatsmodel,h=4,level = c(95))
tbats_forecast
accuracy(tbats_forecast,test)
summary(tbats_forecast)
##normality test
shapiro.test(resid(tbatsmodel))
```

##nnetar
```{r}
nnmodel<-nnetar(train)
nnmodel<-nnetar(train,p=14,P=1,size=7,repeats = 50)
nnforecast<-forecast::forecast(nnmodel,h=4,PI=TRUE,level=c(95))
accuracy(nnforecast,test)
nnmodel<-nnetar(train,p=13,P=2,size=7,repeats = 50)
nnforecast<-forecast::forecast(nnmodel,h=4,PI=TRUE,level=c(95))
accuracy(nnforecast,test)
nnmodel<-nnetar(train,p=16,P=3,size=7,repeats = 50)
nnforecast<-forecast::forecast(nnmodel,h=4,PI=TRUE,level=c(95))
accuracy(nnforecast,test)
nnmodel<-nnetar(train,p=15,P=1,size=6,repeats = 50)
nnforecast<-forecast::forecast(nnmodel,h=4,PI=TRUE,level=c(95))
accuracy(nnforecast,test)
nnmodel<-nnetar(train,p=15,P=1,size=7,repeats = 20)                             
nnforecast<-forecast::forecast(nnmodel,h=4,PI=TRUE,level=c(95))
accuracy(nnforecast,test)
nnmodel<-nnetar(train,p=15,P=1,size=7)
nnforecast<-forecast::forecast(nnmodel,h=4,PI=TRUE,level=c(95))
accuracy(nnforecast,test)
nnmodel<-nnetar(train,p=15,P=1,size=7,repeats = 50)                             #best model
nnforecast<-forecast::forecast(nnmodel,h=4,PI=TRUE,level=c(95))
accuracy(nnforecast,test)

summary(nnforecast)
##normality test
r<-resid(nnmodel)
shapiro.test(r)
```

##forecast plots
```{r}
par(mfrow=c(3,2))

plot(data, flwd=1,main="Forecast of SARIMA")
lines(f_t,col="blue")
lines(f_tr,lty=2, col = "purple")
lines(f_l[,2],col="grey")
lines(f_u[,2],col="grey")
abline(v = c(2016,0), col="red", lwd=3, lty=1)
legend("topleft", lty=1, pch=1,cex = 0.8, col=c(1,"purple","blue","grey","red"), c("Series","Fitted values","Point forecast","95% Prediction interval", "Forecast origin"))
segments(2016,min(f_l[,2]),2016,min(f_u[,2]), lwd=0.5, col="grey", lty=2)
segments(2016.3,f_l[2,2],2016.3,f_u[2,2], lwd=0.5, col="grey", lty=2)
segments(2016.6,f_l[3,2],2016.6,f_u[3,2], lwd=0.5, col="grey", lty=2)
segments(2016.9,max(f_l[,2]),2016.9,max(f_u[,2]), lwd=0.5, col="grey", lty=2)
#######################
plot(data, flwd=1,main="Forecast of ETS")
lines(fr2$mean,col="blue")
lines(fitted(fr2),lty=2, col = "purple")
lines(fr2$lower[,2],col="grey")
lines(fr2$upper[,2],col="grey")
abline(v = c(2016,0), col="red", lwd=3, lty=1)
legend("topleft", lty=1, pch=1,cex = 0.8, col=c(1,"purple","blue","grey","red"), c("Series","Fitted values","Point forecast","95% Prediction interval", "Forecast origin"))
segments(2016,min(fr2$lower[,2]),2016,min(fr2$upper[,2]), lwd=0.5, col="grey", lty=2)
segments(2016.3,fr2$lower[2,2],2016.3,fr2$upper[2,2], lwd=0.5, col="grey", lty=2)
segments(2016.6,fr2$lower[3,2],2016.6,fr2$upper[3,2], lwd=0.5, col="grey", lty=2)
segments(2016.9,max(fr2$lower[,2]),2016.9,max(fr2$upper[,2]), lwd=0.5, col="grey", lty=2)
######################
plot(data, flwd=1,main="Forecast of PROPHET")
lines(forecast_t$yhat,col="blue")
lines(fore,lty=2, col = "purple")
lines(forecast_t$yhat_lower,col="grey")
lines(forecast_t$yhat_upper,col="grey")
abline(v = c(2016,0), col="red", lwd=3, lty=1)
legend("topleft", lty=1, pch=1,cex = 0.8, col=c(1,"purple","blue","grey","red"), c("Series","Fitted values","Point forecast","95% Prediction interval", "Forecast origin"))
segments(2016,min(forecast_t$yhat_lower),2016,min(forecast_t$yhat_upper), lwd=0.5, col="grey", lty=2)
segments(2016.3,forecast_t$yhat_lower[2],2016.3,forecast_t$yhat_upper[2], lwd=0.5, col="grey", lty=2)
segments(2016.6,forecast_t$yhat_lower[3],2016.6,forecast_t$yhat_upper[3], lwd=0.5, col="grey", lty=2)
segments(2016.9,max(forecast_t$yhat_lower),2016.9,max(forecast_t$yhat_upper), lwd=0.5, col="grey", lty=2)
######################
plot(data, flwd=1,main="Forecast of TBATS")
lines(tbats_forecast$mean,col="blue")
lines(fitted(tbats_forecast),lty=2, col = "purple")
lines(tbats_forecast$lower,col="grey")
lines(tbats_forecast$upper,col="grey")
abline(v = c(2016,0), col="red", lwd=3, lty=1)
legend("topleft", lty=1, pch=1,cex = 0.8, col=c(1,"purple","blue","grey","red"), c("Series","Fitted values","Point forecast","95% Prediction interval", "Forecast origin"))
segments(2016,min(tbats_forecast$lower),2016,min(tbats_forecast$upper), lwd=0.5, col="grey", lty=2)
segments(2016.3,tbats_forecast$lower[2],2016.3,tbats_forecast$upper[2], lwd=0.5, col="grey", lty=2)
segments(2016.6,tbats_forecast$lower[3],2016.6,tbats_forecast$upper[3], lwd=0.5, col="grey", lty=2)
segments(2016.9,max(tbats_forecast$lower),2016.9,max(tbats_forecast$upper), lwd=0.5, col="grey", lty=2)
######################
plot(data, flwd=1,main="Forecast of NNETAR")
lines(nnforecast$mean,col="blue")
lines(fitted(nnforecast),lty=2, col = "purple")
lines(nnforecast$lower,col="grey")
lines(nnforecast$upper,col="grey")
abline(v = c(2016,0), col="red", lwd=3, lty=1)
legend("topleft", lty=1, pch=1,cex = 0.8, col=c(1,"purple","blue","grey","red"), c("Series","Fitted values","Point forecast","95% Prediction interval", "Forecast origin"))
segments(2016,min(nnforecast$lower),2016,min(nnforecast$upper), lwd=0.5, col="grey", lty=2)
segments(2016.3,nnforecast$lower[2],2016.3,nnforecast$upper[2], lwd=0.5, col="grey", lty=2)
segments(2016.6,nnforecast$lower[3],2016.6,nnforecast$upper[3], lwd=0.5, col="grey", lty=2)
segments(2016.9,max(nnforecast$lower),2016.9,max(nnforecast$upper), lwd=0.5, col="grey", lty=2)

```


