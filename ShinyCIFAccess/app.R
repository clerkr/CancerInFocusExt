
## app.R ##
library(shiny)          #for shiny apps
library(bslib)          #for boostrap themes
library(leaflet)        #for maps
library(leaflegend)     #for improved legends
library(dplyr)
library(esquisse)       #for color palette selection
library(scales)         #for color palette selection
library(shinydashboard)
library(stringr)
library(htmltools)
library(shinyWidgets)
library(sf)
library(capture)
library(lubridate)
library(pryr)
library(shinyalert)
library(shinyjs)
library(classInt)
library(shinybusy)

### ITEMS TO ADJUST (marked with #!)----
recent = 'October 29, 2024'

ca = 'huntsman' #! catchment area name from CIFTools

# #!#!#! WHEN SAVING THIS FILE AS app.R, remove or comment out the following two lines of code
# path = 'C:/Users/jtburu2/ShinyCIFBivar/CIFwake2/' #! location of Shiny app
# setwd(path)

#encode image for display
b64 <- base64enc::dataURI(file = "www/cif_huntsman_big_logo_light.png", 
                        #! file name for logo
                          mime = "image/png")

#application colors
prim_bg = '#364a6c' #! primary background color
prim_acc = '#8f292d' #! primary accent color

### BEGINNING OF APPLICATION ----
#locate data files
filenames = list.files(path = "./www/locations",pattern="[0-9]{2}\\-[0-9]{2}\\-[0-9]{4}\\.(csv)")

filenames2 = mdy(str_extract(filenames, pattern = "[0-9]{2}\\-[0-9]{2}\\-[0-9]{4}"))

curr = format(max(filenames2), "%m-%d-%Y")

### load geometries----
#load shapefiles
roads_sf = st_read('www/shapefiles/roads_sf.shp')

fd = st_read("www/shapefiles/fd.shp")

state_sf = st_read("www/shapefiles/state_border_sf.shp")

state_df = read.csv('www/data/all_state.csv', header = T) %>% 
  mutate(
    GEOID = str_pad(GEOID, side = 'left', width = 2, pad = '0'),
    RE = case_when(
      RE == 'All' ~ 'All Races',
      .default = RE
    ),
    Sex = case_when(
      Sex == 'All' ~ 'All Sexes',
      .default = Sex
    ))

county_sf = st_read("www/shapefiles/county_sf.shp") 

county_df = read.csv('www/data/all_county.csv', header = T) %>% 
    mutate(
        GEOID = str_pad(GEOID, side = 'left', width = 5, pad = '0')
        ) %>% 
    filter(is.na(Sex) | Sex == 'All',
           is.na(RE) | RE == 'All')

tract_sf = st_read("www/shapefiles/tract_sf.shp") %>% 
    select(GEOID)

tract_df = read.csv('www/data/all_tract.csv', header=T) %>% 
    mutate(
        GEOID = str_pad(GEOID, side = 'left', width = 11, pad = '0'),
    ) 

#calculate bounding box of shapefile
bbox = st_bbox(county_sf$geometry)

### load locations data and subset----
locs = read.csv(paste0(paste0('www/locations/', ca, '_locations_', curr, '.csv')), header=T) %>%
    # filter(dist <= 25 & !is.na(dist)) %>%
    mutate(id = paste0(rownames(.), '_', Name),
           Type2 = case_when(
               Type %in% c('FQHC', 'HPSA Federally Qualified Health Center Look A Like',
                           'HPSA Correctional Facility', 'HPSA Rural Health Clinic') ~ 
                   "FQHCs/Other HPSAs",
               Type %in% c('Colon & Rectal Surgeon', 'Gastroenterology') ~ "GI Providers",
               Type %in% c('Hematology & Oncology', 'Medical Oncology', 'Radiation Oncology',
                           'Surgical Oncology', 'Pediatric Hematology-Oncology', 'Gynecologic Oncology') ~
                   'Oncologists',
               Type == "Lung Cancer Screening" ~ "Lung Cancer Screening",
               Type == "Mammography" ~ "Mammography",
               Type == 'Superfund Site' ~ 'Superfund Sites',
               Type == 'Toxic Release Inventory Facility' ~ 'Toxic Release Inventory Facilities'),
           fcol = case_when(
               Type2 == 'FQHCs/Other HPSAs' ~ "#31bf0a",
               Type2 == 'GI Providers' ~ "#66ccff",
               Type2 == 'Oncologists' ~ 'gray',
               Type2 == 'Lung Cancer Screening' ~ 'white',
               Type2 == 'Mammography' ~ '#ff96a7',
               Type2 == 'Superfund Sites' ~ '#fefe00',
               Type2 == 'Toxic Release Inventory Facilities' ~ '#b200ed'),
           Notes = case_when(
               Type2 == 'Oncologists' ~ Type,
               .default = Notes
           )
    )
### prepare additional items----
#define geo for selectInput
geo = c("County" = "County", "Tract" = "Tract", "State" = "State")

#define facilities
facilities = c('GI Providers', 'Lung Cancer Screening', 'Mammography', 
                "Oncologists")

#create county and tract download files
countyDl = county_df %>% 
    filter(measure == 'Total') %>% 
    select(GEOID, County) %>% 
    rename(FIPS = GEOID, Name = County) %>% 
    mutate(Value = '')

tractDl = tract_df %>% 
    filter(measure == 'Total') %>% 
    select(GEOID, County, Tract) %>% 
    mutate(Name = paste0(County, ', ', Tract),
           Value = '') %>% 
    select(-c(County, Tract)) %>% 
    rename(FIPS = GEOID) 

stateDl = state_df %>%
    filter(measure == 'hadMammogramInTheLastTwoYearsAge40OrOlder') %>%
    select(GEOID, State, measure, value) %>%
    rename(FIPS = GEOID)

#color palette options
palOpts = list(
    "mako" = viridis_pal(begin = 0.2, end = 1, direction = -1, option = 'mako')(9),
    "viridis" = viridis_pal(begin = 0.2, end = 1, direction = -1, option = "viridis")(9),
    "magma" = viridis_pal(begin = 0.2, end = 1, direction = -1, option = "magma")(9),
    "inferno" = viridis_pal(begin = 0.2, end = 1, direction = -1, option = "inferno")(9),
    "plasma" = viridis_pal(begin = 0.2, end = 1, direction = -1, option = "plasma")(9),
    "cividis" = viridis_pal(begin = 0.2, end = 1, direction = -1, option = "cividis")(9),
    "rocket" = viridis_pal(begin = 0.2, end = 1, direction = -1, option = 'rocket')(9),
    "turbo" = viridis_pal(begin = 0.2, end = 1, direction = 1, option = 'turbo')(9),
    "RdBu" = brewer_pal(palette = "RdBu", direction = -1)(8),
    "BrBG" = brewer_pal(palette = "BrBG", direction = -1)(8),
    "PiYG" = brewer_pal(palette = "PiYG", direction = -1)(8),
    "PuRd" = brewer_pal(palette = "PuRd")(8),
    "YlGnBu" = brewer_pal(palette = "YlGnBu")(8),
    "BuGn" = brewer_pal(palette = "BuGn")(8),
    "PuBuGn" = brewer_pal(palette = "PuBuGn")(8),
    "OrRd" = brewer_pal(palette = "OrRd")(8),
    "1989" = manual_pal(c("#637487", "#749dbb", "#beb2a2","#b18e74", "#5d3727"))(5),
    "1989tv" = manual_pal(c("#E4DFD3", "#AFC5D4", "#659BBB", "#487398"))(4),
    "midnights" = manual_pal(c("#d8bfd9", "#9470db", "#4069e1", "#07008b"))(4),
    "ttpd" = manual_pal(c('#e0d5c2', '#b4a584', '#7e6d67', '#362924', '#101010'))(5)
)

### define styles----
styles = tags$head(
    tags$link(rel = "icon", type = "image/png", href = "circle_logo.png"),
    tags$style(
        paste0('#full-bg {background-color:', prim_bg, '; font-size: 1.6vh; height: 100vh;}')
    ),
    tags$style("body {overflow-x: hidden; font-size: 1.6vh;}"),
    tags$style(".picker {font-size: 1.6vh;}"),
    tags$style(".bslib-sidebar-layout.sidebar-collapsed .collapse-toggle {right: -2rem !important;}"),
    tags$style(paste0(".bslib-full-screen-enter {top: 0 !important; left: auto; right: 0 !important; bottom: auto;
               background:", prim_acc, "; color: white; opacity: 1;}")),
    tags$style("#sidemenu {border-color: white;}"),
    tags$style(".dropdown-menu {font-size: 1.6vh; background-color: #ededed; 
               border-color: #1d1f21; --bs-dropdown-link-color: black;"),
    tags$style(".filter-option-inner {padding-right: 3vh;}"),
    tags$style(".sweet-alert h2 {font-size: 3vh !important; color: black !important;}"),
    tags$style(".sweet-alert p {color: black !important;}"),
    tags$style(".info {padding: 0.4vw 0.8vw;}"),
    tags$style(paste0(".btn-light {--bs-btn-color: white; --bs-btn-bg:", prim_acc, "; 
                   --bs-btn-hover-color:", prim_acc, "; --bs-btn-hover-border-color:", prim_acc, ";}")),
    tags$style(".btn-file {--bs-btn-color: #000 !important; --bs-btn-bg: #dee2e6 !important; 
                   --bs-btn-border-color: #dee2e6 !important;}"),
    tags$style(".btn-success {--bs-btn-border-color: white;}"),
    tags$style(".navbar {--bs-navbar-color: #d4d4d4; --bs-navbar-active-color: white; --bs-navbar-hover-color: #f0f0f0;
                   --bs-navbar-brand-color: white; --bs-navbar-brand-hover-color: #f0f0f0;}"),
    tags$style(paste0(".navbar.navbar-default {background-color:", prim_acc, " !important;}")),
    tags$style(".nav-link {--bs-nav-link-font-size: 1.6vh;}"),
    tags$style(paste0(".nav-tabs {--bs-nav-tabs-link-active-color: white; --bs-nav-tabs-link-active-bg:", prim_acc, ";
                   --bs-nav-link-color: #d4d4d4; --bs-nav-link-hover-color: white;")),
    tags$style(".leaflet-container {z-index: 0;}"),
    tags$style(".leaflet-top.leaflet-left {background-color: rgb(255,255,255,0.4) !important;}"),
    tags$style("#polyLegend {background-color: transparent; box-shadow: none; font-weight: bold; font-size: 1.6vh;}"),
    tags$style("#polyLegend img {border: none; border-width: thin;}"),
    tags$style("#polyLegend p {color: #343434;}"),
    tags$style("#markerLegend {background-color: transparent; box-shadow: none; font-weight: bold; font-size: 1.6vh;}"),
    tags$style("#data_title {background-color: transparent; box-shadow: none;}")
)

### define instructions text----
instructions_text = tagList(
    tags$div(
        class = "instructions",
        checked = NA,
        tags$p("Create your own custom data maps by selecting a geographic level, category of 
                           access to care and variables of interest.",
               style = 'text-align: left; font-size: 1.6vh; color: black;'),
        tags$p(HTML("</br>")),
        tags$p("Maps can be zoomed using the scroll button on your mouse or pinch on your 
                                  mobile device. Desktop users can also zoom in on a specific area by holding the Shift 
                                  key and drawing a box with your mouse. To pan the map, click, hold and drag the mouse, 
                                  or use the arrow keys.",
               style = 'text-align: left; font-size: 1.6vh;'),
        tags$p(HTML("</br>")),
        tags$p("Download your map as a PNG using the 'Download Map' button, or download a filtered 
                                  dataset using 'Download Data'. 'Download Map' will download what appears in the mapping 
                                  window at the time it is pressed.",
               style = 'text-align: left; font-size: 1.6vh;'), 
        tags$p(HTML("</br>")),
        tags$p("Any questions regarding this application or the data being used should be directed to 
                                  CancerInFocus@uky.edu.",
               style = 'text-align: left; font-size: 1.6vh;'), 
        tags$p(HTML("</br>")),
        tags$p(paste0("Latest data update: ", recent),
               style = 'text-align: center; font-size: 1.6vh;'), 
        tags$p(HTML("</br>")),
        tags$p("Note: Tract level data on large areas may take a few seconds to display.",
               style = 'text-align: left; font-weight: bold; font-size: 1.6vh;'))
)

### define existing data tabs----
existing_data = tabPanel(
    "Existing Data",
    value = 'og',
    fluidRow(
        style = "margin-bottom: 5.31vh; margin-top: 2.66vh;",
        pickerInput(
            inputId = "geo",
            label = "Select a geographic level",
            choices = geo,
            multiple = F,
            options = pickerOptions(style = 'picker',
                                    size = 4),
            width = "100%"
        ),
        pickerInput(
          inputId = "category",
          label = "Select a category of access",
          choices = c("County Tract closest facility", "Average drive time", 
                      "Broadband accessibility"),
          multiple = FALSE,
          options = pickerOptions(style = 'picker', size = 7),
          width = "100%"
        ),
        pickerInput(
          inputId = "service_type",
          label = "Select a service type",
          choices = c("Mammography", "Lung Cancer Screening", "GI Providers"),
          multiple = FALSE,
          options = pickerOptions(style = 'picker', size = 7),
          width = "100%"
        )
    )
)   

### define settings tab----
settings = tabPanel(
    title = span(tagList(shiny::icon("gear"), "Plot Settings")),
    value = 'setplt',
    fluidRow(
        style = "margin-bottom: 5.31vh; margin-top: 2.66vh;",
        palettePicker(
            inputId = 'palPick',
            label = "Choose a color palette:", 
            choices = list(
                "mako" = viridis_pal(begin = 0.2, end = 1, direction = -1, option = 'mako')(9),
                "viridis" = viridis_pal(begin = 0.2, end = 1, direction = -1, option = "viridis")(9),
                "magma" = viridis_pal(begin = 0.2, end = 1, direction = -1, option = "magma")(9),
                "inferno" = viridis_pal(begin = 0.2, end = 1, direction = -1, option = "inferno")(9),
                "plasma" = viridis_pal(begin = 0.2, end = 1, direction = -1, option = "plasma")(9),
                "cividis" = viridis_pal(begin = 0.2, end = 1, direction = -1, option = "cividis")(9),
                "rocket" = viridis_pal(begin = 0.2, end = 1, direction = -1, option = 'rocket')(9),
                "turbo" = viridis_pal(begin = 0.2, end = 1, direction = 1, option = 'turbo')(9),
                "RdBu" = brewer_pal(palette = "RdBu", direction = -1)(8),
                "BrBG" = brewer_pal(palette = "BrBG", direction = -1)(8),
                "PiYG" = brewer_pal(palette = "PiYG", direction = -1)(8),
                "PuRd" = brewer_pal(palette = "PuRd")(8),
                "YlGnBu" = brewer_pal(palette = "YlGnBu")(8),
                "BuGn" = brewer_pal(palette = "BuGn")(8),
                "PuBuGn" = brewer_pal(palette = "PuBuGn")(8),
                "OrRd" = brewer_pal(palette = "OrRd")(8),
                "1989" = manual_pal(c("#637487", "#749dbb", "#beb2a2","#b18e74", "#5d3727"))(5),
                "1989tv" = manual_pal(c("#E4DFD3", "#AFC5D4", "#659BBB", "#487398"))(4),
                "midnights" = manual_pal(c("#d8bfd9", "#9470db", "#4069e1", "#07008b"))(4),
                "ttpd" = manual_pal(c('#e0d5c2', '#b4a584', '#7e6d67', '#362924', '#101010'))(5)
            ), 
            textColor = 'black',
            pickerOpts = list(style = 'picker', size = 7, iconBase = 'fas')
        ),
        awesomeRadio(
            inputId = "scale",
            label = "Choose a Scale", 
            choices = c('Continuous', 'Discrete (quintiles)'),
            selected = "Continuous",
            inline = TRUE,
            status = 'success'
        )
    )
)

### define instructions tab----
instructions_tab = tabPanel(
    title = span(tagList(shiny::icon("circle-info"), "Info")),
    fluidRow(
        style = 'margin-top: 2.66vh; color: white !important;',
        markdown("Cancer InFocus is a data gathering and visualization software developed by the
                 University of Kentucky Markey Cancer Center and made available to others through
                 a no-cost licensing agreement."),
        markdown("**Citation:**<br>Justin Todd Burus, Lee Park, Caree R. McAfee, 
                 Natalie P. Wilhite, Pamela C. Hull; Cancer InFocus: Tools for 
                 Cancer Center Catchment Area Geographic Data Collection and Visualization. 
                 _Cancer Epidemiol Biomarkers Prev_ 2023")
    ),
    fluidRow(
        style = "margin-top: 2.66vh;",
        column(
            8, offset = 2,
            align = "center",
            actionButton(
                "ins",
                class = 'btn-light',
                "Instructions",
                icon = shiny::icon("list"),
                style = "width: 80%; font-weight: medium; font-size: 1.6vh;"
            )
            )
    ),
    fluidRow(
        style = "margin-top: 2.66vh;",
        column(
            8, offset = 2,
            align = "center",
            actionButton(
                "dataSources",
                class = 'btn-light',
                "Data Sources",
                icon = shiny::icon("spell-check"),
                style = "width: 80%; font-weight: medium; font-size: 1.6vh;",
                onclick = "window.open('https://cancerinfocus.org/datasources/', '_blank')"
            )
        )
    )
)

### define sidebar_selector----
sidebar_selector = sidebar(
    id = "sidemenu",
    width = '33%',
    position = 'left',
    # open = 'always',
    open = list(mobile = "always-above", desktop = 'always'),
    bg = prim_bg,
    max_height_mobile = '100%',
    fluidRow(
        column(
            width = 12,
            align = "center",
            img(
                src = b64,
                align = "center",
                style = "width: 95%; padding-top: 1.06vh; padding-bottom: 1.06vh;"
            )
        )
    ),
    tabsetPanel(
        id = 'tabs',
        type = "tabs",
        #add original tab
        existing_data,
        #add custom data tabs
        navbarMenu('Settings & Info',
                   settings,
                   instructions_tab
        )
    )
)

### define map area----
map_area = function(){
    card(
        full_screen = T,
        leafletOutput("map"),
        absolutePanel(
            draggable = F,
            bottom = '5%', right = '2.5%', height = 'auto', width = 'auto',
            style = 'text-align-last: center;',
            column(
                12,
                capture::capture(
                    id = "mapDl",
                    class = 'btn-light',
                    selector = "#map",
                    format = 'png',
                    filename = "cif_map",
                    scale = 2,
                    style = "font-weight: medium; font-size: 1.6vh;",
                    icon("map"),
                    "Download Map"
                )
            ),
            column(
                12,
                downloadButton(
                    "dd",
                    "Download Data",
                    class = 'btn-light',
                    icon = shiny::icon("table"),
                    style = "font-weight: medium; font-size: 1.6vh;"
                )
            )
        )
    )
}

### write ui----
ui <- page_sidebar(
    useShinyjs(),
    busy_start_up(
        loader = spin_kit(
            spin = "cube-grid", 
            color = "#FFF", 
            style = "width:50px; height:50px;"
        ), 
        text = "Loading...", 
        mode = "auto", 
        color = "#FFF", 
        background = prim_bg 
    ),
    fillable = T,
    fillable_mobile = T,
    window_title = 'Cancer InFocus Access to Care',
    id = 'full-bg',
    theme = bs_theme(version = 5),
    styles,
    sidebar = sidebar_selector,
    map_area()
)

### write server function----
server = function(input, output, session) {
    ### begin server operations----
    ### define initial items----
    #define palette reactive
    my_pal = reactive({
        input$palPick
    })

    #define geo reactive
    geo_to_map <- reactive({
        input$geo
    })
    
    #define cat reactive
    cat_to_map <- reactive({
        input$category
    })
    
    # Define service type reactive
    service_to_map <- reactive({
      input$service_type
    })
    
    #define color scale reactive
    scale_to_color = reactive({
        input$scale
    })
    
    #define reactive values to store map
    vals <- reactiveValues()
    
    #define dataset reactive
    datOut = reactiveValues()
    
    datOut$base = data.frame()
    
    #define popup content for facilities
    facs = function(x){
        paste(sep="</br>",
              paste0("<b>",x$Type2,"</b>"),
              x$Name,
              x$Address,
              paste0('Phone: ', x$Phone_number),
              x$Notes
        )
    }

     #style geography legends
    fd_legend <- '<div style = "display: inline-block; width:3vh; height:2.5vh; background-color: #b7b6b6;
            border: 2px solid black; vertical-align: middle;"></div>
            <span style="font-size: 1.6vh; font-weight: bold; padding-left: 0.53vh">Food Deserts</span>'
    
    rd_legend <- '<div style = "display: inline-block; width:3vh; height:5px; background-color: #a6192e;
            vertical-align: middle;"></div>
            <span style="font-size: 1.6vh; font-weight: bold; padding-left: 0.53vh">Interstates & Highways</span>'
    
    #create palette function
    palFunc = function(data){
        if (scale_to_color() == 'Continuous'){
            pal = colorNumeric(palOpts[[my_pal()]], data$value)
        } else if (scale_to_color() == 'Discrete (quintiles)'){
            nBin = min(5, max(2, length(unique(data$value)[!is.na(data$value)])))
            bins = quantile(data$value, probs = seq(0, 1, 1/nBin), na.rm=T)
            pal = colorBin(palOpts[[my_pal()]], data$value, bins = unique(bins))
        }
        
        return(pal)
    }
    
    #create HTMl link variable
    ds_link = HTML('<a href = "https://cancerinfocus.uky.edu/data-sources/" target="_blank" 
                   rel="noopener noreferrer"> Data Sources </a>')
    
    # create base map
    output$map <- renderLeaflet({
        leaflet(options = leafletOptions(zoomControl = F,
                                         zoomSnap = 0, 
                                         zoomDelta=0.25,
                                         minZoom = 4,
                                         wheelPxPerZoomLevel = 120)) %>%
            addTiles(urlTemplate = "https://{s}.basemaps.cartocdn.com/light_nolabels/{z}/{x}/{y}{r}.png",
                     attribution = c('Copyright 2022, University of Kentucky',
                                     ds_link),
                     options = providerTileOptions(minZoom = 4),
                     group = 'Default') %>% 
            addMapPane("polygons", zIndex = 300) %>%
            addMapPane("borders", zIndex = 320) %>%
            addMapPane("markers", zIndex=330) %>%
            # addScaleBar("bottomleft", options = scaleBarOptions(metric = F, maxWidth = 150)) %>% 
            fitBounds(bbox[[1]]-0.5, bbox[[2]]-0.5, bbox[[3]]+0.5, bbox[[4]]+0.5)

    })
}

### call app----
shinyApp(ui, server)
