library(tidyquant)
library(forecast)
library(TTR)
library(smooth)

# Obtain data from csv to df
pastData <- data.frame(matrix(ncol = 13, nrow = 0))
x <- c("Date", "Time", "Latitude", "Longitude", "Depth",
        "Mag", "TypeMag", "smaj", "smin", "az", "rms", "cPhase", "Region")
colnames(pastData) <- x

for (year in 2008:2018) {
    tempData = read.csv(paste("Data", year, ".csv", sep = ""))
    pastData <- rbind(pastData, tempData)
}

# Specify range of date-time and magnitude
pastData$Date <- as.Date(pastData$Date, format = "%Y-%m-%d")
pastData$DT <- as.POSIXct(paste(pastData$Date, pastData$Time), format = "%Y-%m-%d %H:%M:%OS")
startDateTime <- strptime("2008-1-1 00:00:00", format = "%Y-%m-%d %H:%M:%OS")
endDateTime <- strptime("2018-12-31 00:00:00", format = "%Y-%m-%d %H:%M:%OS")
minMag <- 3
maxMag <- 9

toPlot <- pastData[pastData$DT < endDateTime & pastData$DT > startDateTime & pastData$Mag < maxMag & pastData$Mag > minMag,]

# Get frequency
freqData <- cbind.data.frame(toPlot$Date, toPlot$Region, 1, 0)
colnames(freqData) <- c("Date", "Region", "Frequency", "RegionID")

# Get list of regions
regions <- unique(pastData$Region)

# Map each region from CSV to region to be outputted
regCSV = read.csv("RegionMapping.csv", sep = ",")
for (i in 1:dim(regCSV)[1]) {
    row <- as.numeric(regCSV[i, 2:5])
    for (j in 1:length(row)) {
        if (is.na(row[j])) break
        freqData[freqData$Region %in% regions[row[j]], 4] <- i
    }
}
freqData <- freqData[freqData$RegionID != 0, colnames(freqData) != "Region"]

# Convert date from Date format to ts format (ex: 2008.173)
getTSDate <- function(dateTime) {
    return(year(dateTime) + yday(dateTime) / 364)
}

# Convert date from ts format to Date format (ex: 2008-03-04)
getDateFromTS <- function(dateTime) {
    year <- floor(dateTime)
    noOfWeeks <- floor((dateTime - year) * 365 / 7)
    dt <- as.Date(paste(year, 1, 1, sep = "-"), format = "%Y-%m-%d")
    dt <- dt + weeks(noOfWeeks)
    return(as.Date(dt))
}

getDateFromYearMon <- function(dateTime) {
    return(as.Date(paste(dateTime[1], dateTime[2], "1", sep = "-"), format = "%Y-%m-%d"))
}

# Function to return ts object containing frequency data of region
getRegionData <- function(regionID) {
    regData <- freqData[freqData$RegionID == regionID, colnames(freqData) != "RegionID"]

    # Padding data
    time.min <- freqData$Date[1]
    time.max <- freqData$Date[dim(freqData)[1]]
    allDates <- seq(time.min, time.max, by = "day")
    allDates.frame <- data.frame(list(Date = allDates))
    regData <- merge(allDates.frame, regData, all = TRUE)
    regData$Frequency[which(is.na(regData$Frequency))] <- 0

    regData.xts <- as.xts(x = regData$Frequency, order.by = regData$Date)
    regData.weekly <- apply.weekly(regData.xts, sum)
    #regData.weekly <- tsclean(regData.weekly)

    regData.start <- c(year(start(regData.weekly)), month(start(regData.weekly)), day(start(regData.weekly)))
    regData.end <- c(year(end(regData.weekly)), month(end(regData.weekly)), day(end(regData.weekly)))
    regData.all <- ts(as.numeric(regData.weekly), start = regData.start, end = regData.end, frequency = 52)

    return(regData.all)
}

# Function to return 1-dimensional df containing forecast data based on historical data
getForecast <- function(regData.all, noOfWeeks) {
    weekRange = 26

    # Get start date
    #dt <- as.Date(as.yearmon(time(regData.all)[1]))
    dt <- getDateFromYearMon(start(regData.all))
    regData.start <- c(year(dt), month(dt), day(dt))

    # Get first end date (end date is to be iterated)
    dt <- dt + weeks(weekRange)
    regData.end <- c(year(dt), month(dt), day(dt))
    tempEnd <- regData.end

    finalDateTime <- endDateTime + weeks(noOfWeeks)
    fd <- c()
    fd.upper <- c()

    # Forecast time series with moving-average of order 1
    # Store all forecasts in 1 df for cross-validation
    while (dt <= finalDateTime) {
        ts <- ts(as.numeric(regData.all), start = regData.start, end = tempEnd, frequency = 52)
        fd <- rbind(fd, data.frame(forecast(ma(ts, order = 1), weekRange)$mean[1:weekRange]))
        fd.upper <- rbind(fd.upper, data.frame(forecast(ma(ts, order = 1), weekRange)$upper[1:weekRange, 1]))
        fd.residuals <- forecast(ts, weekRange)$residuals
        dt <- as.Date(paste(tempEnd[1], tempEnd[2], tempEnd[3], sep = "-"), format = "%Y-%m-%d")
        dt <- dt + weeks(weekRange)
        tempEnd <- c(year(dt), month(dt), day(dt))
    }

    names(fd) <- "Frequency"
    names(fd.upper) <- "Frequency"
    fd <- ts(as.numeric(fd$Frequency), start = regData.end, frequency = 52)
    fd.upper <- ts(as.numeric(fd.upper$Frequency), start = regData.end, frequency = 52)

    # Create plot and print accuracy
    png(file = path, width = 800, height = 600, bg = "transparent")
        plot(fd)
        lines(regData.all, col = "red")
    dev.off()

    #acc <- accuracy(fd, ma(regData.all, order = 1))
    #print(acc)
    #hist(fd.residuals)

    # Cut the forecast data to appropriate range
    cutStartDate <- getDateFromYearMon(start(regData.all)) + weeks(weekRange) * 4
    cutEndDate <- getDateFromYearMon(end(regData.all)) + weeks(noOfWeeks)
    finalFd <- window(fd, getTSDate(cutStartDate), getTSDate(cutEndDate))

    # Change negative numbers to 0
    for (i in 1:length(finalFd)) {
        finalFd[i] = max(finalFd[i], 0)
    }

    return(finalFd)
}

# Get forecast for all regions by iteration
for (i in 1:dim(regCSV)[1]) {
    # Path to save plots
    path <- file.path(paste("plot_", i, ".png", sep = ""))

    regDf <- getRegionData(i)
    cleanedRegDf <- tsclean(regDf)
    fd <- getForecast(cleanedRegDf, 52)
    regAcc <- accuracy(fd, cleanedRegDf)

    if (i == 1) {
        pastDf <- data.frame(matrix(ncol = 13, nrow = nrow(data.frame(regDf))))
        forecastDf <- data.frame(matrix(ncol = 13, nrow = nrow(data.frame(fd))))
        acc <- data.frame(matrix(ncol = 3, nrow = 1))
        x <- c("Time", paste("R", 1:12, sep = ""))
        colnames(pastDf) <- x
        colnames(forecastDf) <- x
        colnames(acc) <- c("ME", "RMSE", "MAE")

        pastDf[1] <- round(time(regDf), digits = 3)
        forecastDf[1] <- round(time(fd), digits = 3)
    }

    pastDf[i + 1] <- data.frame(regDf)
    forecastDf[i + 1] <- data.frame(fd)
    acc[i,] <- regAcc[1:3]
}

# Save both original and forecast df to files
saveRDS(pastDf, file = "FreqPast.rds")
saveRDS(forecastDf, file = "FreqForecast.rds")
saveRDS(acc, file = "FreqAccuracy.rds")