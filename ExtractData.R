library(rvest)
library(httr)
library(XML)

# Year range parameters
year = 2008
max_year = 2018

# Iterate to get data from each year
while (year <= max_year) {
    # Log into BMKG website
	session1 <- html_session("http://repogempa.bmkg.go.id/query.php")
	uem = "xxx"
	pwd = "xxx"
	form1 <- html_form(session1)[[1]]
	form1 <- set_values(form1, userid = uem, passwd = pwd)
	session2 <- submit_form(session1, form1)

    # Parameters for webpage search
	#form2 <- html_form(session2)[[1]]
	start_day = "1"
	start_month = "1"
	start_year = year
	end_day = "31"
	end_month = "12"
	end_year = year
	top_lat = "6"
	bot_lat = "-11"
	right_long = "142"
	left_long = "94"
	min_mag = "1"
	max_mag = "9.5"
	min_depth = "1"
	max_depth = "1000"

    # Initialise data frame to store earthquake data
	df <- data.frame(matrix(ncol = 13, nrow = 0))
	x <- c("Date", "Time", "Latitude", "Longitude", "Depth",
		"Mag", "TypeMag", "smaj", "smin", "az", "rms", "cPhase", "Region")
	colnames(df) <- x

    # Iterate to get all pages (page number got from first page in first iteration)
    n = 1
	pageID = 1
    while (pageID <= n) {
        # Get each page by editing the URL and changing page number while keeping other parameters
        # Session ID can be got from website URL after successful login (session2)
		sessionID <- substr(session2$url, nchar(session2$url) - 7, nchar(session2$url))
		url <- paste("http://repogempa.bmkg.go.id/proses_query2.php?",
						"halaman=", pageID,
						"&id=101",
						"&session_id=", sessionID,
						"&output_format=origin",
						"&start_day=", start_day,
						"&start_month=", start_month,
						"&start_year=", start_year,
						"&end_day=", end_day,
						"&end_month=", end_month,
						"&end_year=", end_year,
						"&top_lat=", top_lat,
						"&bot_lat=", bot_lat,
						"&right_long=", right_long,
						"&left_long=", left_long,
						"&min_mag=", min_mag,
						"&max_mag=", max_mag,
						"&min_depth=", min_depth,
                        "&max_depth=", max_depth, sep = "")

        # Save each page as HTML
		sessionPage <- html_session(url)
		capture.output(cat(content(sessionPage$response, as = 'text')), file = "dataHTML.html")

        # Get how many pages are there (for iteration)
        # Page number can be got from 84th line of the page source of first page
		htmlCode = readLines('dataHTML.html')
		pageNumber = htmlCode[84]
		pageNumber <- strsplit(pageNumber, " ")[[1]][5]
		n <- as.numeric(pageNumber)

        # Remove unnecessary header
		length = length(htmlCode) - 17
		newCode = htmlCode[108:length]

        # Remove unnecessary HTML tags
		doc.text = gsub('\\t  ', '', newCode)
		doc.text = gsub('\\t', '', doc.text)
		doc.text = gsub('<tr>', '', doc.text)
		doc.text = gsub('<td class=courier><div align=left>', '', doc.text)
		doc.text = gsub('</div></td>', '', doc.text)
		doc.text = gsub(',', ';', doc.text)
		doc.text = doc.text[which(doc.text != "</tr>")]

        # Insert HTML data into df by iterating per row
		i = 1
        while (i < length(doc.text)) {
            # Extract 1 table row as 1 separate data frame containing only 1 row
			newRow <- data.frame(Date = doc.text[i],
								Time = doc.text[i + 1],
								Latitude = doc.text[i + 2],
								Longitude = doc.text[i + 3],
								Depth = doc.text[i + 4],
								Mag = doc.text[i + 5],
								TypeMag = doc.text[i + 6],
								smaj = doc.text[i + 7],
								smin = doc.text[i + 8],
								az = doc.text[i + 9],
								rms = doc.text[i + 10],
								cPhase = doc.text[i + 11],
                                Region = doc.text[i + 12])
            # Bind above df to existing df (equivalent to adding a row to existing df)
			df <- rbind(df, newRow)
			i = i + 13
		}

		pageID = pageID + 1
	}

    # Export df into csv
	write.csv(df, file = paste("Data", year, ".csv", sep = ""), row.names = FALSE)
	year = year + 1
}
