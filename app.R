library(shiny)
library(shinydashboard)
library(leaflet)
library(geojsonio)

# Shape file edited from https://geonode.wfp.org/layers/geonode%3Aarchive
curRegions <- geojsonio::geojson_read("Regions.json", what = "sp")

# Load files from previous script as df
pastDf <- readRDS(file = "FreqPast.rds")
forecastDf <- readRDS(file = "FreqForecast.rds")
accDf <- readRDS(file = "FreqAccuracy.rds")

# Initialise frequency column
curRegions@data <- as.data.frame(cbind(curRegions@data, rep(0, 12)))
names(curRegions@data)[dim(curRegions@data)[2]] <- "Frequency"

# Year selection for historical and frequency data
yearSelection <- list()
startYear <- floor(pastDf[1,]$Time)
endYear <- floor(pastDf[length(pastDf$Time),]$Time)
yearSelection[[1]] <- c(startYear:endYear)

startYear <- floor(forecastDf[1,]$Time)
endYear <- floor(forecastDf[length(forecastDf$Time),]$Time)
yearSelection[[2]] <- c(startYear:endYear)

# Initialise ID of region which is clicked
regID <- NULL

ui <- fluidPage(
        fluidRow(
            dashboardPage(
                dashboardHeader(
                    title = "Earthquake Frequency",
                    titleWidth = 250
                ),
                dashboardSidebar(
                    selectInput("dataType", "Display", c("Historical", "Forecast")),
                    # Dynamic year selection input based on data type
                    uiOutput("yearSelection"),
                    # Dynamic week slider input based on year and data type
                    uiOutput("weekSlider"),
                    br(),
                    uiOutput("plotImage", align = "center"),
                    htmlOutput("printAcc"),
                    width = 250
                ),
                dashboardBody(
                    # Make height of map fill screen
                    tags$style(type = "text/css", "#map {height: calc(100vh - 80px) !important;}"),
                    leafletOutput("map")
                )
            )
        )
)

server <- function(input, output) {
    # Get available years from year selection list
    output$yearSelection <- renderUI({
        if (input$dataType == "Historical") id = 1
        else id = 2
        selectInput("year", "Year", yearSelection[[id]], selected = input$year)
    })

    # Get minimum and maximum week based on year and data type
    output$weekSlider <- renderUI({
        if (length(input$year) > 0) {
            if (input$year == yearSelection[[1]][1] && input$dataType == "Historical") {
                minDT <- pastDf$Time[1]
                minWeek = round((minDT - floor(minDT)) * 52, digits = 0)
                maxWeek = 51
                sliderInput("week", "Week", min = minWeek, max = maxWeek, value = max(minWeek, input$week))
            }
            else if (input$year == yearSelection[[2]][1] && input$dataType == "Forecast") {
                minDT <- forecastDf$Time[1]
                minWeek = round((minDT - floor(minDT)) * 52, digits = 0)
                maxWeek = 51
                sliderInput("week", "Week", min = minWeek, max = maxWeek, value = max(minWeek, input$week))
            }
            else if (input$year == yearSelection[[1]][length(yearSelection[[1]])] && input$dataType == "Historical") {
                maxDT <- pastDf$Time[length(pastDf$Time)]
                minWeek = 0
                maxWeek = round((maxDT - floor(maxDT)) * 52, digits = 0)
                sliderInput("week", "Week", min = minWeek, max = maxWeek, value = min(maxWeek, input$week))
            }
            else if (input$year == yearSelection[[2]][length(yearSelection[[2]])] && input$dataType == "Forecast") {
                maxDT <- forecastDf$Time[length(forecastDf$Time)]
                minWeek = 0
                maxWeek = round((maxDT - floor(maxDT)) * 52, digits = 0)
                sliderInput("week", "Week", min = minWeek, max = maxWeek, value = min(maxWeek, input$week))
            }
            else {
                minWeek = 0
                maxWeek = 51
                sliderInput("week", "Week", min = minWeek, max = maxWeek, value = input$week)
            }
        }
    })

    # Update earthquake frequency data to show in map from year, week and data type selected
    updateFrequency <- function() {
        if (length(input$year) > 0 && length(input$week) > 0) {
            dateTime <- round(as.numeric(input$year) + (as.numeric(input$week) * 7) / 364, digits = 3)
            if (input$dataType == "Historical") {
                curTimeData <- as.matrix(pastDf[pastDf$Time == dateTime, 2:dim(pastDf)[2]])[1,]
            }
            else {
                curTimeData <- as.matrix(forecastDf[forecastDf$Time == dateTime, 2:dim(forecastDf)[2]])[1,]
            }
            return(curTimeData)
        }
        else
            return(NULL)
    }

    # Get ID of region which is clicked on map
    getRegID <- eventReactive(input$map_shape_click, {
        p <- input$map_shape_click
        regID <- which(curRegions@data$A1NAME == p$id)
        return(regID)
    })

    #TODO - find directory of images
    output$plotImage <- renderUI({
        if (!is.null(getRegID())) {
            regID <- getRegID()
            img(src = paste('plot_', regID, '.png', sep = ""), align = "center", width = 225)
        }
    })

    # Print error of region prediction
    output$printAcc <- renderUI({
        if (!is.null(getRegID())) {
            regID <- getRegID()
            regAcc <- accDf[regID,]
            regAcc <- format(regAcc, digits = 5)
            HTML(paste("<center><h4><b>", curRegions@data$A1NAME[regID],
                 "</h4>ME:</b> ", regAcc[1],
                  "<br/><b>RMSE:</b> ", regAcc[2],
                  "<br/><b>MAE:</b> ", regAcc[3], "</center>", sep = ""))
        }
    })

    output$map <- renderLeaflet({
        # Check if update frequency function has updated with new values (based on new selections)
        # If yes, override current frequency column with new frequency
        df <- updateFrequency()
        if (!is.null(df)) {
            curRegions@data$Frequency <- df
        }

        # Colours and labels
        bins <- c(0, 2, 4, 6, 8, Inf)
        pal <- colorBin("YlOrRd", domain = curRegions$Frequency, bins = bins)
        labels <- sprintf("<strong>%s</strong>", curRegions$A1NAME) %>% lapply(htmltools::HTML)

        # Choropleth map based on frequency data
        m <- leaflet(curRegions) %>%
            # Add maptiles
            addProviderTiles(providers$CartoDB.Positron, group = "Default Maptile") %>%
            addProviderTiles(providers$CartoDB.DarkMatter, group = "Dark Maptile") %>%
            addProviderTiles(providers$Esri.WorldImagery, group = "Satellite Maptile") %>%
            addLayersControl(
                baseGroups = c("Default Maptile", "Dark Maptile", "Satellite Maptile"),
                options = layersControlOptions(collapsed = FALSE)) %>%
            # Set view to zoom on Indonesia
            setView(118, -2, zoom = 5) %>%
            # Draw region shapes on map based on geojson file
            # Region colours based on frequency data
            addPolygons(
                fillColor = ~pal(Frequency),
                weight = 2,
                opacity = 0.8,
                fillOpacity = 0.6,
                #color = "#8b0000",
                #color = "#ff7f00",
                color = "#cc5500",
                layerId = curRegions@data$A1NAME,
                highlight = highlightOptions(
                    weight = 5,
                    fillOpacity = 0.8,
                    bringToFront = TRUE),
                    label = labels,
                    labelOptions = labelOptions(
                        style = list("font-weight" = "normal", padding = "3px 8px"),
                        textsize = "15px",
                        direction = "auto")) %>%
                addLegend(pal = pal, values = ~Frequency, opacity = 0.7,
                    title = NULL, position = "bottomright")
    })
}

# Create Shiny app
shinyApp(ui, server)
#runApp(shinyApp(ui, server), launch.browser = TRUE)