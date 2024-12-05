## app.R ##
library(shiny)    # for shiny apps
library(bslib) #for boostrap themes
library(leaflet)  # renderLeaflet function
library(leaflegend) #for improved legends
library(dplyr)
library(plotly)
library(shinydashboard)
library(stringr)
library(htmltools)
library(shinyWidgets)
library(sf)
library(lubridate)
library(biscale)
library(ggplot2)
library(shinydlplot)
library(pryr)
library(capture)
library(shinyalert)
library(shinyjs)
library(shinybusy)

### ITEMS TO ADJUST (marked with #!)----
recent = 'October 29, 2024'

ca = 'huntsman' #! catchment area name from CIFTools

# #!#!#! WHEN SAVING THIS FILE AS app.R, remove or comment out the following two lines of code
# path = 'C:/Users/jtburu2/ShinyCIFBivar/CIFwake2/' #! location of Shiny app
# setwd(path)

#encode image for display
b64 <- base64enc::dataURI(file = "www/cif_huntsman_bivar_big_logo_light.png", #! file name for logo
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
geo = c("County" = "County", "Tract" = "Tract")

#define facilities
facilities = c('FQHCs/Other HPSAs', 'GI Providers', 'Lung Cancer Screening', 'Mammography', 
               'Oncologists',  'Superfund Sites', 'Toxic Release Inventory Facilities')

tst = data.frame(x = factor(c(rep('Low',16), rep('Mid', 16), rep('High',16)), levels = c('Low', 'Mid', 'High')), 
                 y = factor(c(rep(c('Low', 'Mid', 'Mid', 'High', 'High', 'High'), 8)), levels = c('Low', 'Mid', 'High')))

tst_breaks = bi_class_breaks(tst, style="quantile", x=x, y=y, dim=3)

legendBi <- bi_legend(
    pal = "DkViolet",
    dim = 3,
    xlab = 'X: Low-High',
    ylab = 'Y: Low-High',
    size = 20,
    #breaks = tst_breaks,
    flip_axes = T,
    arrows = T,
    pad_width=1,
    pad_color='#343434'
)

plt = legendBi +
    theme_minimal() +
    theme(
        axis.text = element_blank(),
        text = element_text(face='bold', size=22),
        axis.title.x = element_text(color='#3D8295'),
        axis.title.y = element_text(color='#9C3434'),
        panel.grid = element_blank()
    )

unlink('www/bi.png')
ggsave('www/bi.png', plt, height = 3, width = 3, dpi = 'screen', bg='transparent')

### define styles----
styles = tags$head(
    tags$link(rel = "icon", type = "image/png", href = "circle_logo.png"),
    tags$style(
        paste0('#full-bg {background-color:',prim_bg, '; font-size: 1.6vh; height: 100vh;}')
    ),
    tags$style("body {overflow-x: hidden; font-size: 1.6vh;}"),
    tags$style(".picker {font-size: 1.6vh;}"),
    tags$style(".bslib-sidebar-layout.sidebar-collapsed .collapse-toggle {right: -2rem !important;}"),
    tags$style(paste0(".bslib-full-screen-enter {top: 0 !important; left: auto; right: 0 !important; bottom: auto;
               background:", prim_acc, "; color: white; opacity: 1;}")),
    tags$style("#sidemenu {border-color: white;}"),
    tags$style(".dropdown-menu {font-size: 1.6vh; background-color: #ededed; 
               border-color: #1d1f21; --bs-dropdown-link-color: black;"),
    tags$style(".shiny-options-group {text-align: center; display: block !important; 
               margin-right: auto; margin-left: auto;}"),
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
    tags$style(".js-plotly-plot .plotly .modebar-btn {font-size: 30px !important;}"),
    tags$style(paste0("#tabs {--bs-nav-tabs-link-active-color: white; --bs-nav-tabs-link-active-bg:", prim_acc, ";
                   --bs-nav-link-color: #d4d4d4; --bs-nav-link-hover-color: white;")),
    tags$style(paste0("#tabsMap {--bs-nav-tabs-link-active-color: white; --bs-nav-tabs-link-active-bg:", prim_bg, ";
                   --bs-nav-link-color: black; --bs-nav-link-hover-color:", prim_acc, 
                      "; --bs-nav-pills-link-active-bg:", prim_acc, ";")),
    tags$style(".leaflet-container {z-index: 0;}"),
    tags$style(".leaflet-top.leaflet-left {background-color: transparent !important;}"),
    tags$style("#markerLegend {background-color: transparent; box-shadow: none; font-weight: bold; font-size: 1.6vh;}"),
    tags$style("#data_title {background-color: transparent; box-shadow: none;}"),
    tags$style("#legend {padding: 0.4vw 0.8vw; background: transparent; box-shadow: none; text-align: left;
                   pointer-events: none;}"),
    tags$style("#NA_Color {padding-left: 0.8vw; margin-left: 30px !important; pointer-events: none;}"),
    tags$style(".center {display: block; margin-left: auto; margin-right: auto;}"),
    tags$style("#text{font-size: 1.6vh; text-align: left;}"),
    tags$style("#text2{font-size: 1.6vh; text-align: left;}"),
    tags$style("#exText{font-size: 1.6vh; text-align: left;}"),
    tags$style("#exText2{font-size: 1.6vh; text-align: left;}"),
    tags$style("#exPic{float: left; margin: 1vh;"),
    tags$style("#exScat{display: block; margin-left: auto; margin-right: auto;}")
)

### define instructions text----
instructions_text = tagList(
    tags$div(
        class = "instructions",
        checked = NA,
        tags$p(HTML("(Cancer InFocus)<sup>2</sup> is a reimagining of Cancer InFocus that allows you to visualize
                                  the relationship between two variables at the same time."),
               style = 'text-align: left; font-size: 1.6vh;'),
        tags$p(HTML("</br>")),
        tags$p("Create your own custom bivariate data maps and scatterplots by selecting two variables of interest (X and Y). Data 
                           values will be placed into three categories (Low/Medium/High) for each variable and analyzed, 
                                  helping to reveal possible ecologic associations.",
               style = 'text-align: left; font-size: 1.6vh;'),
        tags$p(HTML("</br>")),
        tags$p("Maps can be zoomed using the scroll button on your mouse or pinch on your 
                                  mobile device. To pan the map, click, hold and drag the mouse, 
                                  or use the arrow keys.",
               style = 'text-align: left; font-size: 1.6vh;'),
        tags$p(HTML("</br>")),
        tags$p("Download your map as a PNG using the 'Download Map' button, or download a filtered 
                                  dataset using 'Download Data'. 'Download Map' will download what appears in the mapping 
                                  window at the time it is pressed. Download your scatterplot by hovering over the graph and 
                                  clicking the camera in the upper righthand corner.",
               style = 'text-align: left; font-size: 1.6vh;'), 
        tags$p(HTML("</br>")),
        tags$p("Any questions regarding this application or the data being used should be directed to 
                                  CIOData@uky.edu.",
               style = 'text-align: left; font-size: 1.6vh;'), 
        tags$p(HTML("</br>")),
        tags$p(paste0("Latest data update: ", recent),
               style = 'text-align: center; font-size: 1.6vh;')
    )
)

### define data tab----
bivar_data = tabPanel(
    "Data",
    value = 'og',
    fluidRow(
        style = "margin-bottom: 5.31vh; margin-top: 2.66vh; align-items: center;",
        awesomeRadio(
            inputId = "geo",
            label = NULL,
            choices = c("County", "Tract"),
            inline = TRUE,
            status = "success"
        ),
        # radioGroupButtons(
        #     inputId = "geo",
        #     label = 'Geography',
        #     choices = c("County", "Tract"),
        #     individual = TRUE,
        #     status = 'success',
        #     checkIcon = list(
        #         yes = tags$i(class = "fa fa-circle"),
        #         no = tags$i(class = "fa fa-circle-o"))
        # ),
        pickerInput(
            inputId = "category",
            label = "Select X variable category",
            choices = unique(county_df$cat),
            multiple = F,
            options = pickerOptions(style = 'picker',
                                    size = 7),
            choicesOpt = list(style = rep_len("font-size: 1.6vh;",
                                              length(
                                                  unique(county_df$cat)
                                              ))),
            width = "100%"
        ),
        pickerInput(
            inputId = "group",
            label = "Select X variable",
            choices = unique(county_df$def),
            multiple = F,
            options = pickerOptions(style = 'picker',
                                    size = 7),
            choicesOpt = list(style = rep_len("font-size: 1.6vh;",
                                              length(
                                                  unique(county_df$def)
                                              ))),
            width = "100%"
        )
    ),
    fluidRow(
        style = "margin-bottom: 5.31vh; align-items: center;",
        pickerInput(
            inputId = "category2",
            label = "Select Y variable category",
            selected = "Cancer Incidence (age-adj per 100k)",
            choices = unique(county_df$cat),
            multiple = F,
            options = pickerOptions(style = 'picker',
                                    size = 7),
            choicesOpt = list(style = rep_len("font-size: 1.6vh;",
                                              length(
                                                  unique(county_df$cat)
                                              ))),
            width = "100%"
        ),
        pickerInput(
            inputId = "group2",
            label = "Select Y variable",
            choices = unique(county_df$def),
            multiple = F,
            options = pickerOptions(style = 'picker',
                                    size = 7),
            choicesOpt = list(style = rep_len("font-size: 1.6vh;",
                                              length(
                                                  unique(county_df$def)
                                              ))),
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
                    "State Borders" = 'sb',
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

### define sidebar selector----
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
                style = "width: 95%;
                          padding-top: 1.06vh; padding-bottom: 1.06vh;"
            )
        )
    ),
    tabsetPanel(
        id = 'tabs',
        type = "tabs",
        #add original tab
        bivar_data,
        #add instructions tabs
        instructions_tab
    )
)

### define map selector----
map_selector = function(){
    navset_card_pill(
        id = 'tabsMap',
        full_screen = T,
        nav_panel(
            "Bivariate Map",
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
        ),
        nav_panel(
            "Scatterplot", 
            fluidRow(id = 'plottab',
                     style = 'margin-top: 1.6vh;',
                     column(3,
                            imageOutput('legendPic', height = '200px'),
                            htmlOutput('text')),
                     column(9,
                            plotlyOutput('scatterly', height = '70vh'))
            )
        ),
        navbarMenu(
            "Details",
            nav_panel("About Bivariate Maps",
                      fluidRow(id = 'exptab',
                               htmlOutput('exText')
                      )
            ),
            nav_panel("About Scatterplots",
                      fluidRow(id = 'exptab2',
                               htmlOutput('exText2')
                      )
            )
        )
    )
}

### Define top navigation bar----
# top_nav = tags$div(class = "topnav", id = "myTopnav",
#     tags$a(href = "http://hci-cancerinfocus.hci.utah.edu:8080/shape/app_direct/cif", style = "background-color: rgba(143, 41, 45, 0.7); color: white;", "Home"),
#     tags$div(class = "dropdown",
#         tags$button(class = "dropbtn", "Other Apps",
#             tags$i(class = "fa fa-caret-down")
#         ),
#         tags$div(class = "dropdown-content",
#             tags$a(href = "http://hci-cancerinfocus.hci.utah.edu:8080/shape/app_direct/profiles", "CIF Profiles"),
#             tags$a(href = "http://hci-cancerinfocus.hci.utah.edu:8080/shape/app_direct/bivariate/", HTML("CIF<sup>2</sup> (bivariate)"))
#             # tags$a(href = "https://cancerinfocus.uky.edu/appalachia", "Appalachia")
#         )
#     ),
#     tags$a(href = "https://cancerinfocus.uky.edu/data-sources/", "Data Sources"),
#     tags$a(href = "https://cancerinfocus.uky.edu/about", "About"),
#     tags$a(href = "javascript:void(0);", style = "font-size:15px;", class = "icon", onclick = "myFunction()", HTML("&#9776;"))
# )

### Define header tags----
# headers = tags$head(
#     tags$link(rel = "stylesheet", type = "text/css", href = "styles.css"),
#     tags$script(src = "script.js")
# )

###write ui----
# ui <- page_fillable(top_nav, page_sidebar(
#     useShinyjs(),
#     busy_start_up(
#         loader = spin_kit(
#             spin = "cube-grid", 
#             color = "#FFF", 
#             style = "width:50px; height:50px;"
#         ), 
#         text = "Loading...", 
#         mode = "auto", 
#         color = "#FFF", 
#         background = prim_bg 
#     ),
#     fillable = T,
#     fillable_mobile = T,
#     window_title = 'Cancer InFocus (bivariate)',
#     id = 'full-bg',
#     theme = bs_theme(version = 5),
#     styles,
#     # headers,
#     sidebar = sidebar_selector,
#     map_selector()
# ))

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
    window_title = 'Cancer InFocus (bivariate)',
    id = 'full-bg',
    theme = bs_theme(version = 5),
    styles,
    sidebar = sidebar_selector,
    map_selector()
)


###write server function----
server = function(input, output, session) {
    ### define initial items----
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
    
    #define cat reactive
    cat_to_map2 <- reactive({
        input$category2
    })
    
    #define group reactive
    group_to_map2 <- reactive({
        input$group2
    })
    
    #create dataset reactive
    datOut = reactiveValues()
    
    datOut$base = data.frame()
    
    #style NA legend
    NA_legend <- '<div style = "display: inline-block; width:3vh; height:3vh; background-color: #a0a0a0;
            border: solid; border-width: thin; vertical-align: middle;"></div>
            <span style="font-size: 1.6vh; font-weight: bold; color: #222222; padding-left: 0.53vh">Data not available</span>'
    
    #style geography legends
    fd_legend <- '<div style = "display: inline-block; width:3vh; height:2.5vh; background-color: #b7b6b6;
            border: 2px solid black; vertical-align: middle;"></div>
            <span style="font-size: 1.6vh; font-weight: bold; padding-left: 0.53vh">Food Deserts</span>'
    
    rd_legend <- '<div style = "display: inline-block; width:3vh; height:5px; background-color: #a6192e;
            vertical-align: middle;"></div>
            <span style="font-size: 1.6vh; font-weight: bold; padding-left: 0.53vh">Interstates & Highways</span>'
    
    #write About Bivariate Maps text
    output$exText = renderUI({
        exStr1 = "</br>Bivariate maps are constructed by taking two county-level variables, 
        classifying their values individually for each county as 'low', 'mid' or 'high' using natural breaks in the data, 
        combining these into pairs of classifications for each county, and mapping them according to the resulting 3x3 grid."
        exStr2 = "<img id='exPic' src='bi.png' width='150vh'>In reading the grid, start at the bottom left-hand corner. 
        Classifications for the first (X) variable selected go low-mid-high as you move to the right
        and classifications for the second (Y) variable go low-mid-high as you move up. 
        Each box in the grid can then be thought of as a combination of these two. For instance, 
        the box in the center represents a county that is classified as mid for the first variable and mid for the second variable."
        exStr3 = "Further explanation of bivariate mappings can be found in the article 
        <a href='https://www.cdc.gov/pcd/issues/2020/19_0254.htm' target='_blank' rel='noopener noreferrer'>'
        A Bivariate Mapping Tutorial for Cancer Control Resource 
        Allocation Decisions and Interventions'</a> by Biesecker <em>et al.</em> (2020)."
        HTML(paste(exStr1, exStr2, exStr3, sep='</br></br>'))
    })
    
    #write About Scatterplots text
    output$exText2 = renderUI({
        exStr1 = "</br>Scatterplots are created by taking counties and plotting them in a coordinate plane according to 
        the values of the first (X) and second (Y) variables selected. This allows users to see the general strength and
        direction of the relationship between the variables across all counties considered.</br></br>
        <img id='exScat' src='scatterplot_example.png' width='65%'></br> Conventionially, if one variable is
        suspected to influence the other, the influencing variable is placed on the X-axis, and the responding variable 
        is placed on the Y-axis."
        exStr2 = "Scatterplots serve as a starting point for a statistical process known as linear regression 
        (e.g. creating a 'line of best fit'). The data necessary to run formal linear regression analysis on the variabes 
        you selected can be obtained via the \"Download Data\" button."
        exStr3 = "<b>It is important to remember that scatterplots only illustrate the strength and 
        direction of the relationship between two variables. They CANNOT be used to make conclusions about
        cause-and-effect.</b>"
        HTML(paste(exStr1, exStr2, exStr3, sep='</br></br>'))
    })
    
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
    
    #reactive values to store map
    vals <- reactiveValues()
    vals2 = reactiveValues() 
    
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
                     options = providerTileOptions(minZoom = 4)) %>%
            addMapPane("polygons", zIndex = 410) %>%
            addMapPane("borders", zIndex = 420) %>%
            addMapPane("markers", zIndex=430) %>%
            fitBounds(bbox[[1]]-0.5, bbox[[2]]-0.5, bbox[[3]]+0.5, bbox[[4]]+0.5) 

    })
    
    ### dynamically filter selections----
    ###select first variable
    observeEvent({
        input$geo
        input$category
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
            choicesOpt = list(
                style = rep_len("font-size: 1.6vh;", 
                                length(unique(vals$dat$cat)))
            ),
            selected = sel
            
        )

        vals$dat1 = vals$dat %>%
            filter(cat == sel)
        
        #update group selection
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
            choicesOpt = list(
                style = rep_len("font-size: 1.6vh;", 
                                length(unique(vals$dat1$def[!is.na(vals$dat1$value)])))
            ),
            selected = sel2
        )
    },
    priority = 10,
    ignoreNULL = F)
    
    ###select second variable
    observeEvent({
        input$geo
        input$category2
    }, {
        #chose correct shapefile
        if (geo_to_map() == 'County') {
            vals2$dat = county_df
        } else if (geo_to_map() == 'Tract') {
            vals2$dat = tract_df
        } 

        #update category selection
        selA = ifelse(
            input$category2 %in% unique(vals2$dat$cat),
            input$category2,
            unique(vals2$dat$cat)[2]
        )
        
        updatePickerInput(
            session,
            "category2",
            choices = unique(vals2$dat$cat),
            choicesOpt = list(
                style = rep_len("font-size: 1.6vh;", 
                                length(unique(vals2$dat$cat)))
            ),
            selected = selA
            
        )
        
        vals2$dat1 = vals2$dat %>%
            filter(cat == selA)
        
        #update group selection
        sel2A = ifelse(
            input$group2 %in% sort(unique(vals2$dat1$def[!is.na(vals2$dat1$value)])),
            input$group2,
            ifelse(
                input$category %in% c('Sociodemographics', 'Screening & Risk Factors',
                                      'Other Health Factors', 'Cancer Incidence (age-adj per 100k)'),
                intersect(unique(vals2$dat1$def), unique(vals2$dat1$def[!is.na(vals2$dat1$value)]))[1],
                sort(unique(vals2$dat1$def[!is.na(vals2$dat1$value)]))[1]
            )
        )
        
        updatePickerInput(
            session,
            "group2",
            choices = if(input$category %in% c('Sociodemographics', 'Screening & Risk Factors',
                                               'Other Health Factors', 'Cancer Incidence (age-adj per 100k)')) {
                intersect(unique(vals2$dat1$def), unique(vals2$dat1$def[!is.na(vals2$dat1$value)]))
            } else {
                sort(unique(vals2$dat1$def[!is.na(vals2$dat1$value)]))
            }, 
            choicesOpt = list(
                style = rep_len("font-size: 1.6vh;", 
                                length(unique(vals2$dat1$def[!is.na(vals2$dat1$value)])))
            ),
            selected = sel2A
        )
    },
    priority = 10,
    ignoreNULL = F)
    
    ### create map layer as viewed by user----
    observeEvent({
        input$geo
        input$category
        input$group
        input$category2
        input$group2
    }, {
        if (input$group %in% unique(vals$dat1$def[!is.na(vals$dat1$value)]) &
            input$group2 %in% unique(vals2$dat1$def[!is.na(vals2$dat1$value)])) {
            
            if (geo_to_map() == 'County'){
                dat2 = county_sf %>% 
                    right_join(vals$dat1, by = 'GEOID') %>%
                    dplyr::filter(def == group_to_map())
            } else if (geo_to_map() == 'Tract'){
                dat2 = tract_sf %>% 
                    right_join(vals$dat1, by = c('GEOID')) %>% 
                    dplyr::filter(def == group_to_map())
            }
            
            dat2a = vals2$dat1 %>%
                dplyr::filter(def == group_to_map2())
            
            if (geo_to_map() == 'County'){
                dat3 = left_join(dat2, dat2a, by=c('GEOID'), suffix = c('','2'))
            } else if (geo_to_map() == 'Tract'){
                dat3 = left_join(dat2, dat2a, by=c('GEOID'), suffix = c('','2')) %>% 
                    tidyr::fill(c(cat, def, fmt, source, cat2, def2, fmt2, source2), .direction = 'downup')
            }
            
            suppressWarnings({
                datBi = bi_class(dat3, x = value, y = value2, style = "fisher", dim = 3, dig_lab = 2)
                
                break_vals <- bi_class_breaks(datBi, style = "fisher",
                                              x = value, y = value2, dim = 3, dig_lab = c(1,1),
                                              split = T)
            })

            datOut$current = dat2 %>%
                st_drop_geometry() %>%
                rbind(dat2a) %>% 
                select(GEOID, County, State, def, value) %>%
                rename(measure = def)

            #configure popups
            content = if (geo_to_map() == 'County'){
                paste0("<b>",datBi$County, "</b></br>", 
                       "<span style='color: #3D8295; font-weight: bold;'>", 
                       datBi$cat, ', ', datBi$def, ': ', datBi$lbl, '</span></br>',
                       "<span style='color: #9C3434; font-weight: bold;'>", 
                       datBi$cat2, ', ', datBi$def2, ': ', datBi$lbl2, "</span>")
            } else if (geo_to_map() == 'Tract'){
                paste0("<b>", datBi$Tract, ", ", datBi$County, "</b></br>", 
                       "<span style='color: #3D8295; font-weight: bold;'>", 
                       datBi$cat, ', ', datBi$def, ': ', datBi$lbl, '</span></br>',
                       "<span style='color: #9C3434; font-weight: bold;'>", 
                       datBi$cat2, ', ', datBi$def2, ': ', datBi$lbl2, "</span>")
            }
            
            #configure source
            source = unique(datBi$source)
            
            #define new label format
            myLabelFormat = function(..., fmt = "int") {
                if (fmt == "pct") {
                    labelFormat(
                        suffix = "%",
                        between = "% - ",
                        transform = function(x) 100 * x,
                        digits = 1
                    )
                } else {
                    labelFormat(...)
                }
            }
            
            #define getLabel
            getLabelX = function(x){
                if (unique(datBi$fmt) == 'pct'){
                    paste0(round(x*100, 1), "%")
                } else {
                    prettyNum(x, big.mark=",", small.mark=".", digits=3, scientific=F)
                }
            }
            
            getLabelY = function(x){
                if (unique(datBi$fmt2) == 'pct'){
                    paste0(round(x*100, 1), "%")
                } else {
                    prettyNum(x, big.mark=",", small.mark=".", digits=3, scientific=F)
                }
            }
            
            #define bivariate palette
            pal = colorFactor(
                palette = c("#cabed0", "#89a1c8", "#4885c1",
                            "#bc7c8f", "#806a8a", "#435786",
                            "#ae3a4e", "#77324c", "#3f2949",
                            '#a0a0a0', '#a0a0a0', '#a0a0a0',
                            '#a0a0a0', '#a0a0a0', '#a0a0a0',
                            '#a0a0a0'),
                levels = c("1-1", "2-1", "3-1",
                           "1-2", "2-2", "3-2",
                           "1-3", "2-3", "3-3",
                           "1-NA", "2-NA", "3-NA",
                           "NA-1", "NA-2", "NA-3",
                           "NA-NA")
            )
            
            ###make bivariate map
            #build legend
            html_legend = paste0("<span style='font-size: 1.6vh; color: #3D8295; font-weight: bold;'>X: ", 
                                  unique(datBi$cat), ', ',
                                  unique(datBi$def), 
                                  "</span></br>", 
                                  "<span style='font-size: 1.6vh; color: #9C3434; font-weight: bold;'>Y: ", 
                                  unique(datBi$cat2), ', ',
                                  unique(datBi$def2), 
                                  "</br></span><img id='mapLegend' src='bi.png' style = 'width: 17vh;'>")
            
            #dynamically add polygons
            leafletProxy("map") %>%
                removeShape(vals$oldId) %>%
                # removeControl('legend') %>%
                clearControls() %>% 
                addPolygons(
                    data = datBi,
                    layerId = unique(datBi$GEOID),
                    stroke = T,
                    color = "#343434",
                    weight = 0.5,
                    opacity = 1,
                    fillColor = ~ pal(datBi$bi_class),
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
                    html = html_legend,
                    position = "topleft",
                    layerId = "legend",
                    className = "info legend",
                ) %>% 
                addControl(
                    html = NA_legend,
                    position = "topleft",
                    layerId = "NA_Color",
                    className = "legend", # or "info NA"
                )
            
            vals$oldId = unique(datBi$GEOID)
            
            ###make scatterplot
            sct = ggplot(datBi, aes(x=value, y=value2, 
                                    # text = content
                                    text = if (geo_to_map() == 'County'){
                                        paste0("<b>",datBi$County, ", ", datBi$State, "</b>: ",
                                               datBi$def, '=', datBi$lbl, '; ',
                                               datBi$def2, '=', datBi$lbl2)
                                    } else if (geo_to_map() == 'Tract'){
                                        paste0("<b>",datBi$Tract, ", ", datBi$County, ", ", datBi$State, "</b>: ",
                                               datBi$def, '=', datBi$lbl, '; ',
                                               datBi$def2, '=', datBi$lbl2)
                                    }
            )) +
                geom_smooth(inherit.aes = F, aes(x=value, y=value2), method = 'lm', formula = 'y~x') +
                geom_point(data = datBi, aes(x=value, y=value2, fill=datBi$bi_class),
                           size = if (geo_to_map() == 'County'){5} else if (geo_to_map() == 'Tract'){3}, 
                           shape = 21, color='black') +
                scale_fill_manual(values = c("1-1" = "#d3d3d3","2-1" = "#98b8c0","3-1" = "#5b9cad",
                                             "1-2" = "#c59595","2-2" = "#8e8288","3-2" = "#556f7a",
                                             "1-3" = "#b65252","2-3" = "#83474a","3-3" = "#4e3d43")) +
                scale_x_continuous(labels = getLabelX) +
                scale_y_continuous(labels = getLabelY)
            
            output$scatterly = renderPlotly({
                xlab = unique(datBi$def)
                ylab = unique(datBi$def2)
                tlab = paste0(unique(datBi$cat), ', ', unique(datBi$def), ' vs </br></br>', 
                              unique(datBi$cat2), ', ', unique(datBi$def2))
                
                ggplotly(sct, tooltip='text') %>%
                    layout(title = HTML(tlab),
                           xaxis = list(title = HTML(xlab), fixedrange = T), 
                           yaxis = list(title = HTML(ylab), fixedrange = T),
                           margin = 2,
                           modebar = list(color = prim_bg, activecolor = prim_acc,
                                          bgcolor = 'transparent'),
                           showlegend = F) %>% 
                    style(hoverinfo = 'text') %>% 
                    config(
                        displaylogo = FALSE,
                        displayModeBar = T,
                        modeBarButtons = list(
                            list("toImage")
                        ),
                        toImageButtonOptions = list(
                            format = 'png',
                            filename = 'cif_scatter',
                            height = 800,
                            width = 1000,
                            scale = 1
                        ),
                        displaylogo = FALSE
                    )
            })
            
            #add scatteplot column elements
            output$legendPic = renderImage({
                list(src = 'www/bi.png',
                     Id = 'plotLegend',
                     contentType = 'image/png',
                     width = 200,
                     height = 200)
            },
            deleteFile=FALSE)
            
            
            output$text = renderUI({
                str1 = "</br></br><b>Note: Correlation &#8800; Causation!</b>"
                str2 = "Scatterplots show patterns in the relationship between two variables. 
                They cannot be used to demonstrate cause-and-effect.
                See the \"About Scatterplots\" tab for more details on how to interpret 
                this visualization."
                HTML(paste(str1, str2, sep='</br>'))
            })
            
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
        
        leafletProxy("map") %>%
            removeMarker(.,locs$id) %>%
            removeControl('markerLegend') %>%
            {
                if (length(intersect(facilities, input$dots)) > 0)
                    addCircleMarkers(
                        .,
                        data = locs[locs$Type2 %in% input$dots,],
                        layerId = locs$id,
                        lng = ~ longitude,
                        lat = ~ latitude,
                        radius = 6,
                        color = '#343434',
                        opacity = 1,
                        weight = 2,
                        fillColor = locs$fcol[locs$Type2 %in% input$dots],
                        fillOpacity = 1,
                        label = lapply(facs(locs[locs$Type2 %in% input$dots,]),HTML),
                        labelOptions = labelOptions(
                            style = list('font-size' = '1.28vh'),
                            direction = 'top'
                        ),
                        popup = facs(locs[locs$Type2 %in% input$dots,]),
                        options = pathOptions(pane = "markers")
                    )
                else
                    .
            } %>%
            { 
                if (length(intersect(facilities, input$dots)) > 0)
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
                        labelStyle = 'font-size: 1.6vh;
                            font-weight: bold;
                            margin-left: 0.53vh;
                            margin-bottom: 0.53vh;
                            color: #343434;
                            box-shadow: 0 0 0px rgba(0,0,0,0.0);'
                    )
                else
                    .
            }
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
                if ('sb' %in% input$bound)
                    addPolygons(
                        .,
                        data = state_sf,
                        layerId = unique(state_sf$STATEFP),
                        stroke = T,
                        color = "#343434",
                        weight = 2,
                        opacity = 1,
                        fill = F,
                        options = pathOptions(pane = "borders")
                    )
                else
                    removeShape(., unique(state_sf$STATEFP))
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
    
    ### pop-up alert with instructions----
    observeEvent(input$ins, {
        shinyalert(HTML("Welcome to (Cancer InFocus)<sup>2</sup>"),
                   text = instructions_text,
                   closeOnClickOutside = T,
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
    
}

### call app----
shinyApp(ui, server)
#> 
#> Listening on http://127.0.0.1:5817