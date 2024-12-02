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
library(lubridate)
library(pryr)
library(capture)
library(shinyalert)
library(shinyjs)
library(classInt)
library(shinybusy)

### ITEMS TO ADJUST (marked with #!)----
recent = 'October 29, 2024' #! date of latest update

ca = 'huntsman' #! catchment area name from CIFTools

#!#!#! WHEN SAVING THIS FILE AS app.R, remove or comment out the following two lines of code
# path = '/srv/external/ShinyCIF/' #! location of Shiny app

# setwd(path)

#encode image for display
b64 <- base64enc::dataURI(file = "www/cif_huntsman_big_logo_light.png", #! file name for logo
                          mime = "image/png")

#application colors
prim_bg = '#364a6c'
prim_acc = '#8f292d'

### BEGINNING OF APPLICATION ----
#locate data files
filenames = list.files(path = "./www/locations",pattern="[0-9]{2}\\-[0-9]{2}\\-[0-9]{4}\\.(csv)")

filenames2 = mdy(str_extract(filenames, pattern = "[0-9]{2}\\-[0-9]{2}\\-[0-9]{4}"))

curr = format(max(filenames2), "%m-%d-%Y")

### load geometries----
#load shapefiles
roads_sf = st_read('www/shapefiles/roads_sf.shp')

fd = st_read("www/shapefiles/fd.shp")

county_sf = st_read("www/shapefiles/county_sf.shp") 

county_df = read.csv('www/data/all_county.csv', header = T) %>% 
    mutate(
        GEOID = str_pad(GEOID, side = 'left', width = 5, pad = '0'),
        RE = case_when(
            RE == 'All' ~ 'All Races',
            .default = RE
        ),
        Sex = case_when(
            Sex == 'All' ~ 'All Sexes',
            .default = Sex
        ))

tract_sf = st_read("www/shapefiles/tract_sf.shp")

tract_df = read.csv('www/data/all_tract.csv', header=T) %>% 
    mutate(
        GEOID = str_pad(GEOID, side = 'left', width = 11, pad = '0'),
    )

#calculate bounding box of shapefile
bbox = st_bbox(county_sf$geometry)

### load locations data and subset----
locs = read.csv(paste0(paste0('www/locations/', ca, '_locations_', curr, '.csv')), header=T) %>%
    filter(dist <= 25 & !is.na(dist)) %>%
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
geo = c("County" = "County", "Tract" = "Tract")

#define facilities
facilities = c('FQHCs/Other HPSAs', 'GI Providers', 'Lung Cancer Screening', 'Mammography', 
               'Oncologists',  'Superfund Sites', 'Toxic Release Inventory Facilities')

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
                           variables and variable of interest. You can also layer in additional geographies and 
                                  location data.",
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
            label = "Select a category of variables",
            choices = unique(county_df$cat),
            multiple = F,
            options = pickerOptions(style = 'picker',
                                    size = 7),
            width = "100%"
        ),
        column(12,
               conditionalPanel(
                   condition = "input.category == 'Cancer Incidence (age-adj per 100k)' ||
                                    input.category == 'Cancer Mortality (age-adj per 100k)'",
                   fluidRow(
                       style = "align-items: center;",
                       column(
                           6,
                           pickerInput(
                               inputId = "re",
                               label = "Select Race/Ethnicity",
                               choices = unique(county_df$RE[county_df$cat[1]]),
                               multiple = F,
                               options = pickerOptions(style = 'picker',
                                                       size = 7),
                               width = "100%",
                               inline = T
                           )
                       ),
                       column(
                           6,
                           pickerInput(
                               inputId = "sex",
                               label = "Select Sex",
                               choices = unique(county_df$Sex[county_df$cat[1]]),
                               multiple = F,
                               options = pickerOptions(style = 'picker',
                                                       size = 7),
                               width = "100%",
                               inline = T
                           )
                       )
                   )
               )

        ),
        pickerInput(
            inputId = "group",
            label = "Select a variable to map",
            choices = unique(county_df$def),
            multiple = F,
            options = pickerOptions(style = 'picker',
                                    size = 7),
            width = "100%"
        )
    ),
    fluidRow(
        style = "margin-bottom: 2.66vh; align-items: center;",
        column(
            6,
            pickerInput(
                inputId = "bound",
                label = "Add geographies",
                choices = c(
                    "County Borders" = 'cb',
                    "Food Deserts" = "fd",
                    "Interstates & Highways" = 'rd'
                ),
                multiple = T,
                options = pickerOptions(
                    style = 'picker',
                    `actions-box` = TRUE,
                    size = 10,
                    `selected-text-format` = "count"
                ),
                width = '100%'
            )
        ),
        column(
            6,
            pickerInput(
                inputId = "dots",
                label = "Add locations",
                choices = facilities,
                multiple = T,
                inline=T,
                options = pickerOptions(
                    # title = 'Add locations',
                    style = 'picker',
                    `actions-box` = TRUE,
                    size = 10,
                    `selected-text-format` = "count"
                ),
                width = "100%"
            )
        )
    )
)

### define custom locations tab----
custom_locs = tabPanel(
    title = span(tagList(shiny::icon("location-dot"), "Locations")),
    value = '24U',
    fluidRow(
        style = 'margin-top: 2.66vh; margin-bottom: 2.66vh;',
        markdown("<h5>Adding Custom Locations</h5>"),
        fileInput(
            inputId = "filedata",
            label = HTML("Upload a CSV of custom location data that includes columns named 'Name', 
                                    'Latitude', and 'Longitude'</br></br>Please confirm that location data is either
                                    publicly-available or de-identified before uploading."),
            accept = c(".csv")
        ),
        textInput("cdataName", "Legend label for custom location data", width = '100%')
    ),
    fluidRow(
        style = "margin-bottom: 2.66vh;",
        column(
            6,
            align = "center", 
            actionButton("applyData", "Add Locations", 
                         class = "btn-light", 
                         icon = shiny::icon("location-dot"),
                         style = "width: 80%; font-weight: medium; font-size: 1.6vh;")
        ),
        column(
            6,
            align = "center", 
            actionButton("resetData", "Clear Locations", 
                         class = "btn-light", 
                         icon = shiny::icon("trash"),
                         style = "width: 80%; font-weight: medium; font-size: 1.6vh;")
        )
    )
)

### define custom layer tab----
custom_layer = tabPanel(
    title = span(tagList(shiny::icon("layer-group"), "Map Layer")),
    value = '24U2',
    fluidRow(
        style = 'margin-top: 2.66vh; margin-bottom: 2.66vh;',
        markdown("<h5>Adding Custom Map Layers</h5>"),
        fileInput(
            inputId = "filedata2",
            label = HTML("Upload a CSV of custom map layer data (county or tract level) that includes columns named 'FIPS', 
                                    'Name', and 'Value'. Templates containing the appropriate FIPS and county/tract names can be 
                                    downloaded below. Areas outside of the existing geographic boundaries will not be rendered.</br></br>Please confirm that map data is either
                                    publicly-available or de-identified before uploading."),
            accept = c(".csv")
        ),
        fluidRow(
            style = "margin-bottom: 2.66vh;",
            column(
                6,
                align = "center", 
                downloadButton(
                    "dlCounty",
                    "County File",
                    class = 'btn-success',
                    icon = shiny::icon("download"),
                    style = "width: 80%; font-weight: medium; font-size: 1.6vh;"
                )
            ),
            column(
                6,
                align = "center", 
                downloadButton(
                    "dlTract",
                    "Tract File",
                    class = 'btn-success',
                    icon = shiny::icon("download"),
                    style = "width: 80%; font-weight: medium; font-size: 1.6vh;"
                )
            )
        ),
        textInput("cdataName2", "Legend label for custom map data", width = '100%'),
        prettyRadioButtons("clevel", "Geographic Level:",
                           c("County" = "ccounty",
                             "Tract" = "ctract"),
                           inline = T,
                           status = 'default',
                           width = '80%'
        )
    ),
    fluidRow(
        style = "margin-bottom: 2.66vh;",
        column(
            6,
            align = "center", 
            actionButton("applyData2", "Add Layer", 
                         class = "btn-light", 
                         icon = shiny::icon("layer-group"),
                         style = "width: 80%; font-weight: medium; font-size: 1.6vh;")
        ),
        column(
            6,
            align = "center", 
            actionButton("resetData2", "Clear Layer", 
                         class = "btn-light", 
                         icon = shiny::icon("trash"),
                         style = "width: 80%; font-weight: medium; font-size: 1.6vh;")
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
        navbarMenu('Custom Data',
                   custom_locs,
                   custom_layer),
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
    window_title = 'Cancer InFocus',
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
    
    #define group reactive
    group_to_map <- reactive({
        input$group
    })
    
    #define re reactive
    re_to_map <- reactive({
        input$re
    })
    
    #define sex reactive
    sex_to_map <- reactive({
        input$sex
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
    
    ### dynamically filter selections----
    observeEvent({
        input$geo
        input$category
        input$sex
        input$re
    }, {
        #chose correct shapefile
        if (geo_to_map() == 'County') {
            vals$dat = county_df
        } else if (geo_to_map() == 'Tract') {
            vals$dat = tract_df
        } 
        
        #update category selection
        sel = ifelse(
            input$category %in% unique(vals$dat$cat),
            input$category,
            unique(vals$dat$cat)[1]
        )
        
        updatePickerInput(
            session,
            "category",
            choices = unique(vals$dat$cat),
            selected = sel
            
        )
        
        vals$datRE = vals$dat %>%
            filter(cat == sel)
        
        #update RE selection
        selRE = ifelse(
            input$re %in% unique(vals$datRE$RE[!is.na(vals$datRE$value)]),
            input$re,
            unique(vals$datRE$RE[!is.na(vals$datRE$value)])[1]
        )
        
        if (!is.na(selRE)){
            updatePickerInput(
                session,
                "re",
                choices = unique(vals$datRE$RE[!is.na(vals$datRE$value)]),
                selected = selRE
            )

            vals$datSex = vals$datRE %>%
                filter(RE == selRE)
        } else {
            updatePickerInput(
                session,
                "re",
                choices = NA
            )
            
            vals$datSex = vals$datRE
        }
        
        #update Sex selection
        selSex = ifelse(
            input$sex %in% unique(vals$datSex$Sex[!is.na(vals$datSex$value)]),
            input$sex,
            unique(vals$datSex$Sex[!is.na(vals$datSex$value)])[1]
        )
        
        if (!is.na(selSex)){
            updatePickerInput(
                session,
                "sex",
                choices = unique(vals$datSex$Sex[!is.na(vals$datSex$value)]),
                selected = selSex
            )

            vals$dat1= vals$datSex %>% 
                filter(Sex == selSex)
        } else {
            updatePickerInput(
                session,
                "sex",
                choices = NA
            )
            
            vals$dat1 = vals$datSex
        }
        
        vals$race = unique(vals$dat1$RE)
        
        vals$sex = unique(vals$dat1$Sex)
        
        #update variable selection
        sel2 = ifelse(
            input$group %in% sort(unique(vals$dat1$def[!is.na(vals$dat1$value)])),
            input$group,
            ifelse(
                input$category %in% c('Sociodemographics', 'Screening & Risk Factors',
                                      'Other Health Factors', 'Cancer Incidence (age-adj per 100k)'),
                intersect(unique(vals$dat1$def), unique(vals$dat1$def[!is.na(vals$dat1$value)]))[1],
                sort(unique(vals$dat1$def[!is.na(vals$dat1$value)]))[1]
            )
        )
        
        updatePickerInput(
            session,
            "group",
            choices = if(input$category %in% c('Sociodemographics', 'Screening & Risk Factors',
                                               'Other Health Factors', 'Cancer Incidence (age-adj per 100k)')) {
                intersect(unique(vals$dat1$def), unique(vals$dat1$def[!is.na(vals$dat1$value)]))
            } else {
                sort(unique(vals$dat1$def[!is.na(vals$dat1$value)]))
            }, 
            selected = sel2
        )
    },
    priority = 10,
    ignoreNULL = F)
    
    ### create map layer as viewed by user----
    observeEvent({
        input$geo
        input$category
        input$group
        input$re
        input$sex
        input$scale
        input$palPick
    }, {
        enable(id = 'scale', asis = T)
        
        if (input$group %in% unique(vals$dat1$def[!is.na(vals$dat1$value)])) {
            if (geo_to_map() == 'County'){
                vals$dat2 = county_sf %>% 
                    right_join(vals$dat1, by = 'GEOID') %>%
                    dplyr::filter(def == group_to_map())
            } else if (geo_to_map() == 'Tract'){
                vals$dat2 = tract_sf %>% 
                    right_join(vals$dat1, by = c('GEOID')) %>%
                    dplyr::filter(def == group_to_map())
            } 
            
            #update dataset for download
            if (geo_to_map() %in% c('County', 'Tract')){
                datOut$current = vals$dat2 %>%
                    st_drop_geometry() %>%
                    select(GEOID, County, State, def, value) %>%
                    rename(measure = def)
            } 
            
            #configure popups
            content = if (geo_to_map() == 'County'){
                paste0("<b>",vals$dat2$County, ", ", vals$dat2$State, ": </b>", vals$dat2$lbl)
            } else if (geo_to_map() == 'Tract'){
                paste0("<b>",vals$dat2$County, ", ", vals$dat2$State, ", ", vals$dat2$Tract, ": </b>", vals$dat2$lbl)
            } 
            
            #configure source
            source = unique(vals$dat2$source)
            
            #define data title
            data_title = htmltools::tags$div(
                class = "title",
                checked = NA,
                tags$p(
                    input$category,
                    style = 'font-size: 1.91vh;
                    text-align: left;
                    margin-bottom: 1.06vh;
                    font-weight: bold;
                    color: #343434'
                ),
                tags$p(
                    input$group,
                    style = 'font-size: 2.23vh;
                    text-align: left;
                    margin-bottom: 1.06vh;
                    font-weight: bold;
                    color: #343434'
                ),
                if (input$category %in% c('Cancer Incidence (age-adj per 100k)',
                                          'Cancer Mortality (age-adj per 100k)')){
                    tags$p(
                        HTML(paste0('(', vals$race, ', ', vals$sex, ')')),
                        style = 'font-size: 1.49vh;
                        text-align: left;
                        margin-bottom: 1.06vh;
                        font-weight: bold;
                        color: #343434'
                    )
                },
                tags$p(
                    source,
                    style = 'font-size: 1.49vh;
                    text-align: left;
                    margin-bottom: 1.06vh;
                    font-weight: bold;
                    color: #343434'
                )
            )    
            
            #dynamically add polygons
            leafletProxy("map") %>%
                removeShape(vals$oldId) %>%
                removeControl('data_title') %>% 
                removeControl('polyLegend') %>%
                addPolygons(
                    data = vals$dat2,
                    layerId = unique(vals$dat2$GEOID),
                    stroke = T,
                    color = "#343434",
                    weight = 0.5,
                    opacity = 1,
                    fillColor = ~palFunc(vals$dat2)(vals$dat2$value),
                    fillOpacity = 1,
                    smoothFactor = 0.2,
                    label = lapply(content,HTML),
                    labelOptions = labelOptions(
                        style = list(
                            'font-size' = '1.28vh'
                        ),
                        direction = 'top'
                    ),
                    popup = content,
                    options = pathOptions(pane = "polygons")
                ) %>% 
                addControl(
                    html = data_title,
                    position = 'topleft',
                    layerId = 'data_title',
                    className = 'info legend'
                ) %>%
                {
                    if (scale_to_color() == 'Continuous')
                        addLegendNumeric(
                            .,
                            layerId = 'polyLegend',
                            position = 'topleft',
                            pal = palFunc(vals$dat2),
                            values = vals$dat2$value,
                            tickWidth = 0,
                            # tickLength = 0,
                            # bins = 4,
                            decreasing = F,
                            naLabel = 'No Data',
                            # title = data_title,
                            orientation = 'horizontal',
                            width = 200,
                            height = 20,
                            numberFormat = if (unique(vals$dat2$fmt) == 'int'){
                                function(x) {
                                    prettyNum(x, big.mark = ",", scientific = FALSE, digits = 1)
                                    }
                                } else {
                                    function(x) {
                                        paste0(round(x * 100, 1), "%")
                                    }
                                    }
                            )
                    else
                        addLegendBin(
                            .,
                            pal = palFunc(vals$dat2),
                            values = vals$dat2$value,
                            layerId = 'polyLegend',
                            naLabel = 'No Data',
                            labelStyle = 'font-size: 1.6vh; font-weight: bold; vertical-align: middle;',
                            position = "topleft",
                            orientation = "vertical",
                            numberFormat = if (unique(vals$dat2$fmt) == 'int'){
                                function(x) {
                                    prettyNum(x, big.mark = ",", scientific = FALSE, digits = 1)
                                }
                            } else {
                                function(x) {
                                    paste0(round(x * 100, 1), "%")
                                }
                            },
                            opacity = 1
                        )
                } 


            
            vals$oldId = unique(vals$dat2$GEOID)
            
            print(mem_used())
        }
    },
    ignoreNULL = F)
    
    ### dynamically add locations----   
    observeEvent({
        input$dots
    }, {
        palf = colorFactor(
            palette = c("gray", "#31bf0a", "#66ccff",
                         "white", "#ff96a7",
                         "#fefe00", '#b200ed'),
            levels = c("Oncologists", "FQHCs/Other HPSAs", "GI Providers",
                       "Lung Cancer Screening", "Mammography",
                       "Superfund Sites", "Toxic Release Inventory Facilities")
        )
        
        vals$locs = subset(locs, locs$Type2 %in% input$dots)
        
        leafletProxy("map") %>%
            removeMarker(., vals$oldLocsId) %>% 
            removeControl('markerLegend') %>%
            addCircleMarkers(
                .,
                data = vals$locs,
                layerId = vals$locs$id,
                lng = ~ longitude,
                lat = ~ latitude,
                radius = 6,
                color = '#343434',
                opacity = 1,
                weight = 2,
                fillColor = vals$locs$fcol,
                fillOpacity = 1,
                label = lapply(facs(vals$locs),HTML),
                labelOptions = labelOptions(
                    style = list('font-size' = '1.28vh'),
                    direction = 'top'
                ),
                popup = facs(vals$locs),
                options = pathOptions(pane = "markers"),
                group = 'facilities'
            )  %>%
            addLegendSymbol(
                .,
                pal = palf,
                color = '#343434',
                layerId = 'markerLegend',
                values = input$dots,
                orientation = "vertical",
                position = "bottomleft",
                opacity=1,
                shape = rep("circle", 7),
                group = 'facilities',
                labelStyle = 'font-size: 1.6vh;
                            font-weight: bold;
                            margin-left: 0.53vh;
                            margin-bottom: 0.53vh;
                            color: #343434;
                            box-shadow: 0 0 0px rgba(0,0,0,0.0);'
            )
        
        vals$oldLocsId = unique(vals$locs$id)
    },
    ignoreNULL = F,
    ignoreInit = F)
    
    ### dynamically add geographies----
    observeEvent({
        input$bound
    }, {
        leafletProxy("map") %>%
            {
                if ('cb' %in% input$bound)
                    addPolygons(
                        .,
                        data = county_sf,
                        layerId = paste0(unique(county_sf$GEOID), '_border'),
                        stroke = T,
                        color = "#343434",
                        weight = 2,
                        opacity = 1,
                        fill = F,
                        options = pathOptions(pane = "borders")
                    )
                else
                    removeShape(., paste0(unique(county_sf$GEOID), '_border'))
            } %>%
            {
                if ('fd' %in% input$bound)
                    addPolygons(
                        .,
                        data = fd,
                        layerId = "fdR",
                        stroke = T,
                        color = "black",
                        weight = 2,
                        opacity = 1,
                        fill = '#b7b6b6',
                        fillOpacity = 0.15,
                        label = 'Food Desert',
                        labelOptions = labelOptions(
                            direction = 'top'
                        ),
                        options = pathOptions(pane = "borders")
                    ) %>% 
                    addControl(
                        html = fd_legend,
                        position = "topright",
                        layerId = "fdColor",
                        className = 'geoLegends'
                    )
                else
                    removeShape(., 'fdR') %>% 
                    removeControl('fdColor')
            } %>% 
            {
                if ('rd' %in% input$bound)
                    addPolylines(
                        .,
                        data = roads_sf,
                        layerId = paste0('road', unique(roads_sf$LINEARID)),
                        stroke = T,
                        color = "#a6192e",
                        weight = 3,
                        opacity = 1,
                        label = roads_sf$FULLNAME,
                        labelOptions = labelOptions(
                            direction = 'top'
                        ),
                        options = pathOptions(pane = "borders")
                    ) %>% 
                    addControl(
                        html = rd_legend,
                        position = "topright",
                        layerId = "rdColor",
                        className = 'geoLegends'
                    )
                else
                    removeShape(., paste0('road', unique(roads_sf$LINEARID))) %>% 
                    removeControl('rdColor')
            }
    },
    ignoreNULL = F,
    ignoreInit = F)
    
    ### custom locations----
    # add custom locations
    observeEvent({
        input$applyData
    }, {
        req(input$filedata)
        
        if(input$filedata$type == 'text/csv'){
            clocs = reactive({
                df = read.csv(input$filedata$datapath) 
                
                colnames(df) = str_to_sentence(colnames(df))
                
                df2 = df %>% 
                    {
                        if ('Name' %in% colnames(.))
                            mutate(., id = paste0(rownames(.), '_', Name)) 
                        else
                            .
                    } %>% 
                    {
                        if ('Latitude' %in% colnames(.))
                            rename(., Lat = Latitude)
                        else
                            .
                    } %>% 
                    {
                        if ('Longitude' %in% colnames(.))
                            rename(., Long = Longitude)
                        else
                            .
                    }
                
                tryCatch({
                    df3 = df2 %>% 
                        mutate(Lat = as.numeric(Lat),
                               Long = as.numeric(Long))
                    
                    return(df3)
                },
                error = function(err){})
            })
            
            
            if (all(c('Name', 'Lat', 'Long') %in% colnames(clocs()))){
                
                cpal = colorFactor(
                    palette = c('#D4AF37'),
                    levels = c(input$cdataName)
                )
                
                leafletProxy("map") %>%
                    removeMarker(vals$oldLocs) %>%
                    removeControl('cmarkerLegend') %>%
                    addCircleMarkers(
                        data = clocs(),
                        layerId = clocs()$id,
                        lng = ~ Long,
                        lat = ~ Lat,
                        radius = 6,
                        color = 'black',
                        opacity = 1,
                        weight = 2,
                        fillColor = '#D4AF37',
                        fillOpacity = 1,
                        label = clocs()$Name,
                        labelOptions = labelOptions(
                            style = list('font-size' = '1.28vh'),
                            direction = 'top'
                        ),
                        popup = clocs()$Name,
                        options = pathOptions(pane = "markers")
                    ) %>%
                    addLegendSymbol(
                        pal = cpal,
                        color = '#343434',
                        layerId = 'cmarkerLegend',
                        values = input$cdataName,
                        orientation = "vertical",
                        position = "bottomleft",
                        opacity=1,
                        shape = 'circle',
                        labelStyle = 'font-size: 1.6vh;
                        font-weight: bold;
                        margin-left: 0.53vh;
                        margin-bottom: 0.53vh;
                        color: #343434;
                        box-shadow: 0 0 0px rgba(0,0,0,0.0);'
                    )
                
                vals$oldLocs = clocs()$id
                
            } else {
                shinyalert("Incorrect Column Names",
                           text = tagList(
                               tags$div(
                                   class = "badFileCols",
                                   checked = NA,
                                   tags$p("The file you uploaded did not contain the appropriate column names for mapping. 
                                      Please try again.",
                                          style = 'text-align: center; font-size: 1.6vh;')
                               )
                           ),
                           closeOnClickOutside = T,
                           html = T,
                           size = 's',
                           className = "badFileCols")
                
                reset('filedata')
                reset('cdataName')
            }
        } else {
            shinyalert("Incorrect File Type",
                       text = tagList(
                           tags$div(
                               class = "badFileType",
                               checked = NA,
                               tags$p("The file you uploaded was not a CSV.",
                                      style = 'text-align: center; font-size: 1.6vh;')
                           )
                       ),
                       closeOnClickOutside = T,
                       html = T,
                       size = 's',
                       className = "badFileType")
            
            reset('filedata')
            reset('cdataName')
        }
    },
    ignoreNULL = T,
    ignoreInit = T)
    
    # remove custom locations
    observeEvent({
        input$resetData
    }, {
        req(input$filedata)
        
        leafletProxy("map") %>%
            removeMarker(vals$oldLocs) %>%
            removeControl('cmarkerLegend')
        
        reset('filedata')
        reset('cdataName')
    },
    ignoreNULL = T,
    ignoreInit = T)
    
    ### custom map layer----
    # add custom map layer
    observeEvent({
        input$applyData2
    }, {
        disable(id = 'scale', asis = T)
        
        req(input$filedata2)
        
        if(input$filedata2$type == 'text/csv'){
            clayer = reactive({
                df = read.csv(input$filedata2$datapath) 
                
                colnames(df) = str_to_lower(colnames(df))
                
                tryCatch({
                    if (input$clevel == 'ccounty'){
                        df2 = df %>% 
                            mutate(fips = str_pad(fips, pad = '0', width = 5, side = 'left'),
                                   value = as.numeric(value))
                        
                        df3 = county_sf %>% 
                            left_join(df2, by = c('GEOID' = 'fips'))
                        
                        return(df3)
                    } else {
                        df2 = df %>% 
                            mutate(fips = str_pad(fips, pad = '0', width = 11, side = 'left'),
                                   value = as.numeric(value))
                        
                        df3 = tract_sf %>% 
                            left_join(df2, by = c('GEOID' = 'fips'))
                        
                        return(df3)
                    }
                },
                error = function(err){})
            })
            
            if (all(c('GEOID', 'name', 'value') %in% colnames(clayer())) & !all(is.na(clayer()$value))){
                
                #configure popups
                content2 = paste0("<b>",clayer()$name, ": </b>", clayer()$value)
                
                #dynamically add polygons
                leafletProxy("map") %>%
                    removeShape(vals$oldId) %>%
                    removeControl('data_title') %>% 
                    removeControl('polyLegend') %>%
                    addPolygons(
                        data = clayer(),
                        layerId = unique(clayer()$GEOID),
                        stroke = T,
                        color = "#343434",
                        weight = 0.5,
                        opacity = 1,
                        fillColor = ~ palFunc(clayer())(clayer()$value),
                        fillOpacity = 1,
                        smoothFactor = 0.2,
                        label = lapply(content2,HTML),
                        labelOptions = labelOptions(
                            style = list(
                                'font-size' = '1.28vh'
                            ),
                            direction = 'top'
                        ),
                        popup = content2,
                        options = pathOptions(pane = "polygons")
                    ) %>%
                    addControl(
                        html = htmltools::tags$div(
                            class = "title",
                            checked = NA,
                            tags$p(
                                input$cdataName2,
                                style = 'font-size: 1.91vh;
                                            text-align: left;
                                            margin-bottom: 1.06vh;
                                            font-weight: bold;
                                            color: #343434'
                            )
                        ),
                        position = 'topleft',
                        layerId = 'data_title',
                        className = 'info legend'
                    ) %>% 
                    {
                        if (scale_to_color() == 'Continuous')
                            addLegendNumeric(
                                .,
                                layerId = 'polyLegend',
                                position = 'topleft',
                                pal = palFunc(clayer()),
                                values = clayer()$value,
                                tickWidth = 0,
                                tickLength = 0,
                                naLabel = 'No Data',
                                orientation = 'horizontal',
                                width = 200,
                                height = 20
                            )
                        else
                            addLegendBin(
                                .,
                                pal = palFunc(clayer()),
                                values = clayer()$value,
                                layerId = 'polyLegend',
                                naLabel = 'No Data',
                                labelStyle = 'font-size: 1.6vh; font-weight: bold; vertical-align: middle;',
                                position = "topleft",
                                orientation = "vertical",
                                opacity = 1
                            )
                    }
                
                vals$oldId = unique(clayer()$GEOID)
                
            } else {
                shinyalert("Check Your Input!",
                           text = tagList(
                               tags$div(
                                   class = "badFileMap",
                                   checked = NA,
                                   tags$p("The file you uploaded failed to render! Your column names may be incorrect, 
                                      you may have chosen the wrong geographic level, or you may have input a region outside
                                      of the geographic bounds of this application. Please try again.",
                                          style = 'text-align: left; font-size: 1.6vh;')
                               )
                           ),
                           closeOnClickOutside = T,
                           html = T,
                           size = 's',
                           className = "badFileMap")
                
                reset('filedata2')
                reset('cdataName2')
            }
        } else {
            shinyalert("Incorrect File Type",
                       text = tagList(
                           tags$div(
                               class = "badFileType",
                               checked = NA,
                               tags$p("The file you uploaded was not a CSV.",
                                      style = 'text-align: center; font-size: 1.6vh;')
                           )
                       ),
                       closeOnClickOutside = T,
                       html = T,
                       size = 's',
                       className = "badFileType")
            
            reset('filedata2')
            reset('cdataName2')
        }
    },
    ignoreNULL = T,
    ignoreInit = T)
    
    ### remove custom map layer
    observeEvent({
        input$resetData2
    }, {
        req(input$filedata2)
        
        reset('filedata2')
        reset('cdataName2')
    },
    ignoreNULL = T,
    ignoreInit = T)
    
    ### pop-up alert with instructions----
    observeEvent(input$ins, {
        shinyalert("Instructions",
                   text = instructions_text,
                   closeOnClickOutside = F,
                   html = T,
                   size = 's',
                   className = "inst")
    },
    ignoreNULL = T)
    

    ### create filtered dataset download----
    output$dd <- downloadHandler(
        filename = function() {
            "data_download.csv"
        },
        content = function(file) {
            write.csv(datOut$current, file, row.names = FALSE)
        }
    )
    
    ### create custom county and tract downloads----
    output$dlCounty <- downloadHandler(
        filename = function() {
            "county_file.csv"
        },
        content = function(file) {
            write.csv(countyDl, file, row.names = FALSE)
        }
    )
    
    output$dlTract <- downloadHandler(
        filename = function() {
            "tract_file.csv"
        },
        content = function(file) {
            write.csv(tractDl, file, row.names = FALSE)
        }
    )

}

### call app----
shinyApp(ui, server)
# shiny::runApp(display.mode="showcase")
#> 
#> Listening on http://127.0.0.1:5817