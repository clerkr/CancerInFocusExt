## app.R ##
library(shiny)    # for shiny apps
library(bslib) #for boostrap themes
library(dplyr)
library(DT)
library(ggplot2)
library(forcats)
library(plotly)
library(leaflet)  # renderLeaflet function
library(leaflegend) #for improved legends
library(sf)
library(shinydashboard)
library(stringr)
library(htmltools)
library(rmarkdown)
library(shinyWidgets)
library(pryr)
library(capture)
library(shinyalert)
library(shinyjs)
library(shinybusy)

### ITEMS TO ADJUST (marked with #!)----
recent = 'October 29, 2024' #! date of latest update

ca = 'huntsman' #! catchment area name from CIFTools

#!#!#! WHEN SAVING THIS FILE AS app.R, remove or comment out the following two lines of code
# path = 'C:/Users/jtburu2/ShinyCIFProfiles/CIFwakePro/' #! location of Shiny app
# setwd(path)

#encode image for display
b64 <- base64enc::dataURI(file = "www/cif_huntsman_profiles.png", mime = "image/png") #! file name for logo

#give name of logo for report
reportLogo = 'cif_huntsman_big_logo.png' #! file name for report logo

#application colors
prim_bg = '#364a6c' #! primary background color
prim_acc = '#8f292d' #! primary accent color

### BEGINNING OF APPLICATION ----
### load geometries----
#load shapefiles
countyDf = read.csv("www/data/county_median.csv", header=T) %>% 
    mutate(GEOID = as.character(GEOID)) %>% 
    filter(Sex == 'All'|is.na(Sex),
           RE == 'All'|is.na(RE)) %>% 
    mutate(area = paste0(area, ", ", State))

county_sf = st_read("www/shapefiles/county_sf.shp") %>% 
    left_join(countyDf[countyDf$measure == 'Total', c('GEOID', 'area')], by = 'GEOID') %>% 
    select(GEOID, area, geometry)

#calculate bounding box of shapefile
bbox = st_bbox(county_sf$geometry)

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
    tags$style("button.varSel {border-color: #1d1f21;"),
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
                   --bs-nav-link-color: black; --bs-nav-link-hover-color:", prim_acc, "; 
                      --bs-nav-pills-link-active-bg:", prim_acc, ";")),
    tags$style(".leaflet-container {z-index: 0;}"),
    tags$style(".leaflet-top.leaflet-left {background-color: transparent !important;}"),
    tags$style(".info {padding: 0.4vw 0.8vw;}"),
    tags$style("#table{padding-bottom: 1vh;}"),
    tags$style("#areaText{font-size: 2.1vh; font-weight: bold; padding-bottom: 1vh;}"),
    tags$style("#text{font-size: 2.1vh; font-weight: bold;}"),
    tags$style("#text2{font-size: 1.6vh;}"),
    tags$style(paste0("#text3{color:", prim_acc, "; font-size: 2.1vh; font-weight: bold;}"))
)

### define instructions text----
instructions_text = tagList(
    tags$div(
        class = "instructions",
        checked = NA,
        tags$p(
            "Create your own custom Cancer InFocus data profile for a county or Area Development
                               District by selecting a geographic level, category of variables and area of interest.",
            style = 'text-align: left; font-size: 1.6vh;'
        ),
        tags$p(HTML("</br>")),
        tags$p("Areas can be selected using the dropdown menu or by clicking them on the map.",
               style = 'text-align: left; font-size: 1.6vh; font-weight: bold;'),
        tags$p(HTML("</br>")),
        tags$p(
            "Data for the selected area and category of variables can be viewed in the 'Data Table' tab. You can also view
                        the distribution of individual variables across the chosen geographic level by clicking
                        the 'Variable Graph' tab. This will give you a bar graph of area values and indicate
                        where the chosen area falls among them. You may download the graph generated here using the 'Download Graph' button.",
            style = 'text-align: left; font-size: 1.6vh;'
        ),
        tags$p(HTML("</br>")),
        tags$p(
            "The 'Create Data Profile' button will generate a PDF output containing all available variables,
                        grouped by category, for your chosen area. Or you can click the 'Download Dataset' button
                        to receive the same data in a CSV file.",
            style = 'text-align: left; font-size: 1.6vh;'
        ),
        tags$p(HTML("</br>")),
        tags$p(
            "Any questions regarding this application or the data being used should be directed to
                        CancerInFocus@uky.edu.",
            style = 'text-align: left; font-size: 1.6vh;'
        ), 
        tags$p(HTML("</br>")),
        tags$p(paste0("Latest data update: ", recent),
               style = 'text-align: center; font-size: 1.6vh;')
    )
)

### define data tab----
profile_data = tabPanel(
    title = span(tagList(shiny::icon("house"), "Home")),
    value = 'og',
    fluidRow(
        style = "margin-top: 2.66vh; margin-bottom: 5.31vh",
        pickerInput(
            inputId = "area",
            label = "Select a specific area",
            choices = unique(countyDf$area),
            multiple = F,
            options = pickerOptions(style = 'picker',
                                    size = 7),
            choicesOpt = list(style = rep_len("font-size: 1.6vh;",
                                              length(
                                                  unique(countyDf$area)
                                              ))),
            width = "100%"
        )
    ),
    fluidRow(
        style = "margin-bottom: 2.66vh;",
        column(
            10,
            offset = 1,
            align = "center",
            downloadButton(
                outputId = "report",
                icon = shiny::icon("file"),
                label = " Create Data Profile",
                class = 'btn-light',
                style = "width: 80%; font-weight: medium; font-size: 1.6vh;"
            )
        )
    ),
    fluidRow(
        style = "margin-bottom: 2.66vh;",
        column(
            10,
            offset = 1,
            align = "center",
            downloadButton(
                "dd",
                " Download Dataset",
                icon = shiny::icon("table"),
                class = 'btn-light',
                style = "width: 80%; font-weight: medium; font-size: 1.6vh;"
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
                style = "width: 70%;
                          padding-top: 1.06vh; padding-bottom: 1.06vh;"
            )
        )
    ),
    tabsetPanel(
        id = 'tabs',
        type = "tabs",
        #add original tab
        profile_data,
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
            "Map of Areas",
            value = 'panel_map',
            leafletOutput("map")
        ),
        nav_panel(
            "Data Table",
            value = 'panel_table',
            textOutput('areaText'),
            dataTableOutput("table")
        ),
        nav_panel(
            "Bar Graphs",
            value = 'panel_graph',
            fluidRow(
                style = 'margin-top: 1.06vh; margin-bottom: 1.06vh;',
                column(
                    5, offset = 1,
                    align = 'left',
                    pickerInput(
                        inputId = "category",
                        label = "Select a category of variables",
                        width = "100%",
                        inline = T,
                        choices = unique(countyDf$cat),
                        multiple = F,
                        options = list(
                            pickerOptions(style = 'picker', size = 7),
                            style = 'varSel'
                        ),
                        choicesOpt = list(style = rep_len("font-size: 1.6vh;",
                                                          length(
                                                              unique(countyDf$cat)
                                                          )))
                    )
                ),
                column(
                    5, offset = 1,
                    align = 'left',
                    pickerInput(
                        inputId = "group",
                        label = "Select a variable to graph: ",
                        width = "100%",
                        inline = T,
                        choices = unique(countyDf$def),
                        multiple = F,
                        options = list(
                            pickerOptions(style = 'picker', size = 7),
                            style = 'varSel'
                        ),
                        choicesOpt = list(style = rep_len("font-size: 1.6vh;",
                                                          length(
                                                              unique(countyDf$def)
                                                          )))
                    )
                )
            ), 
            plotlyOutput(outputId = 'histo')
        )
    )
}

###write ui----
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
    window_title = 'CIF Profiles',
    id = 'full-bg',
    theme = bs_theme(version = 5),
    styles,
    sidebar = sidebar_selector,
    map_selector()
)

###write server function----
server = function(input, output, session) {
    
    #define area reactive
    area_to_map <- reactive({
        input$area
    })
    
    #define cat reactive
    cat_to_map <- reactive({
        input$category
    })
    
    #define group reactive
    group_to_map <- reactive({
        input$group
    })
    
    #reactive values to store map
    vals <- reactiveValues()
    
    #create HTMl link variable
    ds_link = HTML('<a href = "https://cancerinfocus.uky.edu/data-sources/" target="_blank" 
                   rel="noopener noreferrer"> Data Sources </a>')
    
    # create base map
    bbox = st_bbox(county_sf$geometry)
    
    output$map <- renderLeaflet({
        leaflet(options = leafletOptions(zoomControl = F,
                                         zoomSnap = 0, 
                                         zoomDelta=0.25,
                                         minZoom = 4,
                                         wheelPxPerZoomLevel = 120)) %>%
            addTiles(urlTemplate = "https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png", 
                     attribution = c('Copyright 2022, University of Kentucky',
                                     ds_link),
                     options = providerTileOptions(minZoom = 4)) %>%
            addMapPane("polygons", zIndex = 440) %>%
            addMapPane("borders", zIndex = 420) %>%
            addMapPane("markers", zIndex=430) %>%
            fitBounds(bbox[[1]]-0.5, bbox[[2]]-0.5, bbox[[3]]+0.5, bbox[[4]]+0.5) %>% 
            addPolygons(
                data = county_sf,
                layerId = unique(county_sf$GEOID),
                stroke = T,
                color = prim_bg,
                weight = 2,
                opacity = 1,
                label = county_sf$area,
                labelOptions = labelOptions(
                    style = list(
                        'font-size' = '1.28vh'
                    ),
                    direction = 'top'
                ),
                popup = NULL,
                options = pathOptions(pane = "polygons")
            )
        })
    
    #create dataset reactive
    datOut = reactiveValues()
    
    datOut$base = data.frame()
    
    ### dynamically filter selections----
    observeEvent({
        input$category
        input$group
        input$area
    }, {
        #chose correct shapefile
        vals$dat = countyDf
        
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
            choicesOpt = list(
                style = rep_len("font-size: 1.6vh;", 
                                length(unique(vals$dat1$def[!is.na(vals$dat1$value)])))
            ),
            selected = sel2
        )
        
        #update area selection
        sel3 = ifelse(
            input$area %in% unique(vals$dat1$area),
            input$area,
            sort(unique(vals$dat1$area))[1]
        )
        
        updatePickerInput(
            session,
            "area",
            choices = sort(unique(vals$dat1$area)),
            choicesOpt = list(
                style = rep_len("font-size: 1.6vh;", 
                                length(unique(vals$dat1$area)))
            ),
            selected = sel3
            
        )

        if (input$group %in% unique(vals$dat1$def[!is.na(vals$dat1$value)])) {
            vals$dat2 = vals$dat1 %>%
                dplyr::filter(def == group_to_map()) %>% 
                mutate(hlt = ifelse(area == sel3, 1, 0))
            
            # define output texts
            output$areaText = renderText({area_to_map()})
            
            vals$text = paste0(area_to_map(), ': ', 
                               vals$dat2$lbl[vals$dat2$area == area_to_map()],
                               "  (Catchment Median: ",
                               vals$dat2$med_lbl[vals$dat2$area == area_to_map()],
                               ")")
            
            # prepare histogram
            if (unique(vals$dat2$fmt == 'pct')){
                y_scale = scales::percent
            } else if (unique(vals$dat2$fmt == 'int')){
                y_scale = scales::comma
            }

            output$histo <- renderPlotly({
                plt = ggplot(vals$dat2, aes(x = fct_rev(fct_reorder(area, value, .na_rm=F)), 
                                            y=value, 
                                            fill = as.factor(hlt),
                                            text = paste0(area, ": ", lbl))) +
                    geom_bar(position = 'dodge', stat = 'identity') +
                    labs(title = NULL,
                         x = NULL,
                         y = NULL) +
                    scale_y_continuous(labels = y_scale) +
                    scale_fill_manual(values = c('#adadad', prim_acc)) +
                    theme(
                        legend.position = "none",
                        text = element_text(size = 10),
                        axis.text.x=element_blank(),
                        axis.ticks.x=element_blank()
                    ) 
                
                ggplotly(plt, tooltip = "text") %>%
                    config(
                        displaylogo = FALSE,
                        displayModeBar = T,
                        modeBarButtons = list(
                            list("toImage")
                        ),
                        toImageButtonOptions = list(
                            format = 'png',
                            filename = 'cif_scatter',
                            # height = 800,
                            # width = 1000,
                            scale = 1
                        ),
                        displaylogo = FALSE
                    ) %>% 
                    layout(
                        margin = list(t = 60, b = 60),
                        # paper_bgcolor = 'transparent',
                        xaxis = list(
                            title = list(
                                text = vals$text, 
                                font = list(size = 18, color = prim_acc)
                            ), 
                            fixedrange = TRUE
                        ), 
                        yaxis = list(fixedrange = TRUE),
                        title = list(
                            text = paste0(unique(vals$dat2$cat), ": ", unique(vals$dat2$def),
                                          " (", unique(vals$dat2$source), ")"),
                            font = list(color = 'black')
                        ),
                        modebar = list(color = prim_bg, activecolor = prim_acc,
                                       bgcolor = 'transparent')
                    )
            })
            
            # prepare table
            vals$dat3 = countyDf %>% 
                filter(area == area_to_map()) %>% 
                {
                    if (!(cat_to_map() %in% c('Sociodemographics', 'Screening & Risk Factors',
                                              'Other Health Factors', 'Cancer Incidence (age-adj per 100k)')))
                        arrange(., def)
                    else
                        .
                } %>% 
                select(cat, def, lbl, med_lbl) %>% 
                mutate(cat = as.factor(cat),
                       def = as.factor(def)) %>% 
                rename(
                    Category = cat,
                    Variable = def,
                    Value = lbl,
                    Catchment_Median_Value = med_lbl
                )
            
            output$table <- renderDataTable(DT::datatable(
                vals$dat3,
                rownames = F,
                class = 'display',
                colnames = c('KY Median' = 'Catchment_Median_Value'),
                options = list(
                    deferRender = TRUE,
                    scrollY = '55vh',
                    scroller = TRUE,
                    ordering = F,
                    columnDefs = list(list(className = 'dt-center', targets = 2:3))
                )
            )
            )
            
            #update dataset for download
            datOut$current = countyDf %>% 
                filter(area == area_to_map()) %>% 
                select(area, State, cat, def, lbl, med_lbl) %>% 
                rename(Variable = def,
                       Value = lbl,
                       Catchment_Median_Value = med_lbl)
        }
    },
    ignoreNULL = F)
    
    # update area selection on map click
    observeEvent(
        input$map_shape_click,{
            vals$click = input$map_shape_click
            
            if (!is.null(vals$click$id)){
                sel4 = unique(vals$dat1$area[vals$dat1$GEOID == vals$click$id])
                
                updatePickerInput(
                    session,
                    "area",
                    choices = sort(unique(vals$dat1$area)),
                    choicesOpt = list(
                        style = rep_len("font-size: 1.6vh;",
                                        length(unique(vals$dat1$area)))
                    ),
                    selected = sel4
                )
            }
        },
        ignoreNULL = T
    )
    
    # place pop-up and highlight on area selection
    observeEvent({
        input$area
        input$tabsMap},{
            if (input$tabsMap == "panel_map"){
                vals$point = st_coordinates(st_centroid(county_sf$geometry[county_sf$area == input$area])) 
                vals$ht = subset(county_sf, county_sf$area == input$area)
                
                leafletProxy('map') %>%
                    clearPopups() %>% 
                    clearGroup("highlighted") %>% 
                    addPopups(
                        lng = vals$point[1],
                        lat = vals$point[2],
                        input$area,
                        options = popupOptions(
                            closeButton = F,
                            maxwidth = 500,
                            closeOnClick = F
                        ) 
                    ) %>% 
                    addPolygons(
                        stroke=TRUE, 
                        weight = 2,
                        color = prim_bg,
                        fillColor = prim_acc,
                        fillOpacity = 0.5,
                        data=vals$ht,
                        group="highlighted",
                        options = pathOptions(pane = "polygons")
                    )
            } else {
                leafletProxy('map') %>%
                    clearPopups() %>% 
                    clearGroup("highlighted")
            }
        }
    )
    
    #pop-up alert with instructions
    observeEvent(input$ins, {
        shinyalert(
            "Instructions",
            text = instructions_text,
            closeOnClickOutside = T,
            html = T,
            size = 's',
            className = "inst"
        )
    },
    ignoreInit = T,
    ignoreNULL = F)
    
    #generate report
    output$report <- downloadHandler(
        filename <-  "CIFreport.pdf",
        content = function(file) {
            withProgress(message = 'Creating data profile...', {
                tempReport <- file.path(tempdir(), "CIFReport.Rmd")
                tempPic = file.path(tempdir(), reportLogo)
                file.copy("www/CIFReport_v5.Rmd", tempReport, overwrite = TRUE)
                file.copy(paste0('www/',reportLogo), tempPic, overwrite = TRUE)
                params <- list(datCIF = datOut$current)
                rmarkdown::render(
                    tempReport,
                    output_file = file,
                    params = params,
                    envir = new.env(parent = globalenv())
                )
            })
        }
    )
    
    #create filtered dataset download
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