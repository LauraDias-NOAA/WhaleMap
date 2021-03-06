# static map - english/french version

build_static_map = function(type = 'whalemap'){
  
  # translation -------------------------------------------------------------
  
  if(type == 'dfo-en' | type == 'whalemap'){
    
    # define category names
    acoustic_lab = 'Acoustic'
    visual_lab = 'Visual'
    
    # basemap title
    main_title = 'Right whale observations'
    date_title = 'Data from:'
    
    # robot popup labels
    robot_main = 'Latest position'
    robot_date = 'Time: '
    robot_position = 'Position: '
    
    # robot popup labels
    rw_main = 'Right whale'
    rw_number = 'Number of whales: '
    rw_calves = 'Number of calves: '
    rw_date = 'Date: '
    rw_position = 'Position: '
    
    # define basemap
    can_basemap_url = "https://geoappext.nrcan.gc.ca/arcgis/rest/services/BaseMaps/CBMT_CBCT_GEOM_3857/MapServer/tile/{z}/{y}/{x}?m4h=t"
    can_labels_url = "https://geoappext.nrcan.gc.ca/arcgis/rest/services/BaseMaps/CBMT_TXT_3857/MapServer/tile/{z}/{y}/{x}?m4h=t"
    can_attribution_url = "https://www.nrcan.gc.ca/earth-sciences/geography/topographic-information/free-data-geogratis/licence/17285"
    can_attribution_txt = "Canada Base Map © Natural Resources Canada"
    
    # basemap labels
    basemap_grp = 'Canada'
    blank_grp = 'Basemap'
    oceanmap_grp = 'Ocean basemap'
    
    # define layer labels
    survey_grp = 'Survey tracks'
    robot_grp = 'Latest robot positions'
    graticules_grp = 'Graticules'
    rw_grp = 'Right whale observations'
    mpa_grp = 'Protected areas'
    tss_grp = 'Shipping lanes'
    tc_zone_grp = 'Speed reduction zones'
    dfo_zone_grp = 'Area subject to temporary fishery closure protocol'
    
    # output path
    if(type == 'whalemap'){
      fout = './static_map/whalemap.html'  
    } else {
      fout = './static_map/whale_map_en.html'  
    }
    
  } else if(type == 'dfo-fr'){
    
    # define category names
    acoustic_lab = 'Acoustique'
    visual_lab = 'Visuelle'
    
    # basemap title
    main_title = 'Observation des baleines noires'
    date_title = 'Données de:'
    
    # robot popup labels
    robot_main = 'Position la plus récente'
    robot_date = 'Heure: '
    robot_position = 'Position: '
    
    # robot popup labels
    rw_main = 'Baleine noire'
    rw_number = 'Nombre de baleines: '
    rw_calves = 'Nombre de baleineaux: '
    rw_date = 'Date: '
    rw_position = 'Position: '
    
    # define basemap
    can_basemap_url = "https://geoappext.nrcan.gc.ca/arcgis/rest/services/BaseMaps/CBMT_CBCT_GEOM_3857/MapServer/tile/{z}/{y}/{x}?m4h=t"
    can_labels_url = "https://geoappext.nrcan.gc.ca/arcgis/rest/services/BaseMaps/CBCT_TXT_3857/MapServer/tile/{z}/{y}/{x}?m4h=t"
    can_attribution_url = "https://www.nrcan.gc.ca/earth-sciences/geography/topographic-information/free-data-geogratis/licence/17285"
    can_attribution_txt = "La Carte de Base du Canada © Ressources naturelles Canada"
    
    # basemap labels
    basemap_grp = 'Canada'
    blank_grp = 'Fond de carte'
    oceanmap_grp = 'Fond de l\'océan'
    
    # define layer labels
    survey_grp = 'Trajets suivis'
    robot_grp = 'Positions les plus récentes des robots'
    graticules_grp = 'Graticules'
    rw_grp = 'Observations de baleines noires'
    mpa_grp = 'Zones protégées'
    tss_grp = 'Couloirs de navigation'
    tc_zone_grp = 'Zones de réduction de vitesse'
    dfo_zone_grp = 'Zones soumises au protocole de fermeture temporaire'
    
    # output path
    fout = './static_map/whale_map_fr.html'
  } else {
    stop('Unknown type! Please choose from \'whalemap\', \'dfo-en\', or \'dfo-fr\' ')
  }
  
  # setup -------------------------------------------------------------------
  
  # required libraries
  suppressPackageStartupMessages(library(leaflet))
  suppressPackageStartupMessages(library(rgdal))
  suppressPackageStartupMessages(library(htmltools))
  suppressPackageStartupMessages(library(htmlwidgets))
  suppressPackageStartupMessages(library(maptools))
  suppressPackageStartupMessages(library(lubridate))
  suppressPackageStartupMessages(library(oce))
  suppressPackageStartupMessages(library(leaflet.extras))
  
  # time period to show (days)
  t1 = as.Date(format(Sys.time(), "%Y-%m-%d", tz = 'UTC'))
  t0 = t1-14
  
  # define score color palette
  obs_levs = c(acoustic_lab, visual_lab)
  obs_pal = c('red', 'darkslategray')
  pal = colorFactor(levels = obs_levs,
                    palette = obs_pal)
  
  # make dcs icons
  dcsIcons = iconList(
    slocum = makeIcon("icons/slocum.png", iconWidth = 38, iconHeight = 38),
    wave = makeIcon("icons/wave.png", iconWidth = 35, iconHeight = 30),
    buoy = makeIcon("icons/buoy.png", iconWidth = 44, iconHeight = 34, iconAnchorX = 22, iconAnchorY = 28)
  )
  
  # define function to determine trackline color
  getColor <- function(tracks) {
    if(tracks$platform[1] == 'slocum') {
      "blue"
    } else if(tracks$platform[1] == 'plane') {
      "#8B6914"
    } else if(tracks$platform[1] == 'vessel'){
      "black"
    } else if(tracks$platform[1] == 'wave'){
      "purple"
    } else {
      "darkgrey"
    }
  }
  
  # hidden platforms
  hidden_platforms = c('cp_king_air', 'jasco_test')
  
  # create destination directory
  outdir = dirname(fout)
  if(!dir.exists(outdir)){dir.create(outdir)}
  
  # read in data -------------------------------------------------------
  
  # read in map data
  load('data/processed/tss.rda')
  load('data/processed/gis.rda')
  
  # tracklines
  tracks = readRDS('data/processed/tracks.rds')
  
  # latest dcs positions
  lfile = 'data/processed/dcs_live_latest_position.rds'
  if(file.exists(lfile)){
    latest = readRDS(lfile)
    latest = latest[!(latest$name %in% hidden_platforms),] # do not plot test data
  }
  
  # sightings / detections
  obs = readRDS('data/processed/observations.rds')
  
  # subset data -------------------------------------------------------------
  
  # tracklines
  Tracks = tracks[tracks$date >= t0,]; rm(tracks)
  Tracks = Tracks[!(Tracks$name %in% hidden_platforms),] # do not plot test data
  
  # observations
  Obs = obs[obs$date >= t0,]; rm(obs)
  Obs = Obs[!(Obs$name %in% hidden_platforms),] # do not plot test data
  
  # select species
  spp = Obs[Obs$species == 'right',]
  
  # only definite
  det = droplevels(spp[!spp$score %in% c('possible acoustic', 'possible visual'),])
  
  # rename factor levels
  det$score = gsub(pattern = 'definite visual', replacement = visual_lab, x = det$score)
  det$score = gsub(pattern = 'definite acoustic', replacement = acoustic_lab, x = det$score)
  det$score = as.factor(det$score) 
  
  # basemap -----------------------------------------------------------------
  
  # start basemap
  map <- leaflet() %>%
    
    # add canada gov tiles
    addTiles(urlTemplate = can_basemap_url, group = basemap_grp) %>%
    addTiles(urlTemplate = can_labels_url, group = basemap_grp,
             attribution = paste0('<a href=\"', can_attribution_url, '\">', can_attribution_txt, '</a>')) %>%
    
    # add other provider tiles
    addProviderTiles(providers$CartoDB.PositronNoLabels, group=blank_grp) %>%
    addProviderTiles(providers$Esri.OceanBasemap, group=oceanmap_grp) %>%
    
    # title and last updated message
    addControl(position = "topright",
               paste0(
                 '<div align="center">',
                 '<strong>', main_title, '</strong>','<br>',
                 '<small>', date_title,'<br>',
                 format(t0, '%Y-%m-%d'), ' - ',
                 format(t1, '%Y-%m-%d'), '</small>',
                 '</div>'))
  
  # layer control
  if(type == 'whalemap'){
    map <- map %>% addLayersControl(
      baseGroups = c(
        oceanmap_grp,
        basemap_grp,
        blank_grp
      ),
      overlayGroups = c(survey_grp,
                        robot_grp,
                        rw_grp,
                        mpa_grp,
                        tss_grp,
                        tc_zone_grp,
                        dfo_zone_grp),
      options = layersControlOptions(collapsed = TRUE), position = 'topright')
  } else {
    map <- map %>% addLayersControl(
      baseGroups = c(
        basemap_grp,
        blank_grp,
        oceanmap_grp
      ),
      overlayGroups = c(survey_grp,
                        robot_grp,
                        rw_grp,
                        mpa_grp,
                        tss_grp,
                        tc_zone_grp,
                        dfo_zone_grp
      ),
      options = layersControlOptions(collapsed = TRUE), position = 'topright')
  }
  
  # hide groups
  map <- map %>% hideGroup(c(survey_grp,
                     graticules_grp,
                     robot_grp,
                     tc_zone_grp,
                     dfo_zone_grp)) %>%
    
    # add legend
    addLegend(position = "bottomright",
              pal = pal,
              values = obs_levs) %>%
    
    # add extra map features
    addScaleBar(position = 'bottomleft')%>%
    addFullscreenControl(pseudoFullscreen = F)
  
  # center on entire region
  map <- setView(map = map, lng = -65, lat = 45, zoom = 5)
  
  # plot polygons -----------------------------------------------------------
  
  # add mpas
  map <- map %>%
    addPolygons(data=critical_habitat_zone, group = mpa_grp,
                fill = T, fillOpacity = 0.25, stroke = T, smoothFactor = 0,
                dashArray = c(5,5), options = pathOptions(clickable = F),
                weight = 1, color = 'darkgreen', fillColor = 'darkgreen')
  
  # plot shipping lanes
  
  map <- map %>%
    addPolylines(tss_lines$lon, tss_lines$lat,
                 weight = .5,
                 color = 'grey',
                 smoothFactor = 0,
                 options = pathOptions(clickable = F),
                 group = tss_grp) %>%
    addPolygons(tss_polygons$lon, tss_polygons$lat,
                weight = .5,
                color = 'grey',
                fillColor = 'grey',
                smoothFactor = 0,
                options = pathOptions(clickable = F),
                group = tss_grp)
  
  # plot tc zone
  map <- map %>%
    addPolygons(data=tc_zone, group = tc_zone_grp,
                fill = T, fillOpacity = 0.25, stroke = T, smoothFactor = 0,
                dashArray = c(2,2), popup = ~paste0(ID),
                weight = 1, color = 'darkgreen', fillColor = 'darkgreen')
  
  # plot dfo_zone
  map <- map %>%
    addPolygons(data=dfo_zone, group = dfo_zone_grp,
                fill = T, fillOpacity = 0.25, stroke = T, smoothFactor = 0,
                dashArray = c(2,2), options = pathOptions(clickable = F),
                weight = 1, color = 'darkblue', fillColor = 'darkblue')
  
  # add tracks --------------------------------------------------------------
  
  # set up track plotting
  tracks.df <- split(Tracks, Tracks$id)
  
  # add lines
  names(tracks.df) %>%
    purrr::walk( function(df) {
      map <<- map %>%
        addPolylines(data=tracks.df[[df]], group = survey_grp,
                     lng=~lon, lat=~lat, weight = 2,
                     smoothFactor = 1, color = getColor(tracks.df[[df]]))
    })
  
  # add platform icons ------------------------------------------------------
  
  if(file.exists(lfile)){
    
    # add icons for latest position of live dcs platforms
    map <- map %>% addMarkers(data = latest, ~lon, ~lat, icon = ~dcsIcons[platform],
                              popup = ~paste(sep = "<br/>",
                                             strong(robot_main),
                                             paste0(robot_date, 
                                                    as.character(time), ' UTC'),
                                             paste0(robot_position,
                                                    as.character(round(lat,2)), ', ', 
                                                    as.character(round(lon,2)))
                              ),
                              group = robot_grp)
  }
  
  # add definite detections/sightings ---------------------------------------
  
  map <- map %>% addCircleMarkers(data = det, ~lon, ~lat, group = rw_grp,
                                  radius = 4, fillOpacity = 0.9, stroke = T, col = 'black', weight = 0.5,
                                  fillColor = pal(det$score),
                                  popup = ~paste(sep = "<br/>" ,
                                                 strong(rw_main),
                                                 paste0(rw_number, number),
                                                 paste0(rw_calves, calves),
                                                 paste0(rw_date, as.character(date)),
                                                 paste0(rw_position,
                                                        as.character(round(lat,2)), ', ', 
                                                        as.character(round(lon,2)))
                                  ),
                                  options = markerOptions(removeOutsideVisibleBounds=T))
  
  # save widget -------------------------------------------------------------
  
  # normalize output path
  FOUT = file.path(normalizePath(dirname(fout)),basename(fout))
  
  # save widget
  saveWidget(widget = map, file = FOUT, selfcontained = T)
}

# build english map
suppressWarnings(build_static_map(type = 'whalemap'))
suppressWarnings(build_static_map(type = 'dfo-en'))
suppressWarnings(build_static_map(type = 'dfo-fr'))

