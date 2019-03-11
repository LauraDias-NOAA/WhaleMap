## proc_2019_noaa_twin_otter ##
# Process gps and sightings data from NOAA Twin Otter survey plane

# user input --------------------------------------------------------------

# data directory
data_dir = 'data/raw/2019_noaa_twin_otter/edit_data/WhaleMap/'

# output file names
track_file = '2019_noaa_twin_otter_tracks.rds'
sighting_file = '2019_noaa_twin_otter_sightings.rds'

# output directory
output_dir = 'data/interim/'

# setup -------------------------------------------------------------------

suppressPackageStartupMessages(library(lubridate))
suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(tools))
suppressPackageStartupMessages(library(readxl))
source('functions/config_data.R')
source('functions/subsample_gps.R')

# process -----------------------------------------------------------------

# list all flight directories
flist = list.files(data_dir, full.names = TRUE, recursive = FALSE)

# list output column names for sightings
cnames = c('time','lat','lon','date', 'yday','species','score','number','year','platform','name','id')

TRK = list()
SIG = list()
for(i in seq_along(flist)){
  
  # isolate file
  ifile = flist[i]
  
  # determine file extension
  ext = file_ext(ifile)
  
  # read in data
  if(ext == 'csv'){
    tmp = read.csv(ifile, stringsAsFactors = FALSE)
  } else {
    tmp = read_excel(ifile, guess_max = 4e3)
  }
  
  # wrangle time
  tmp$time = as.POSIXct(tmp$DateTime, format = '%Y-%m-%d %H:%M:%S', tz = 'UTC', usetz = T)
  
  # try a different format if previous did not work
  if(is.na(tmp$time[1])){
    tmp$time = as.POSIXct(tmp$DateTime, format = '%m/%d/%Y %H:%M', tz = 'UTC', usetz = T)
  }
  
  # other time vars
  tmp$date = as.Date(tmp$time)
  tmp$yday = yday(tmp$time)
  tmp$year = year(tmp$time)
  
  # add deployment metadata
  tmp$platform = 'plane'
  tmp$name = 'noaa_twin_otter'
  tmp$id = paste(tmp$date, tmp$platform, tmp$name, sep = '_')
  
  # extract lat/lon
  tmp$lat = tmp$LATITUDE
  tmp$lon = tmp$LONGITUDE
  
  # get speed and altitude
  tmp$altitude = tmp$ALTITUDE
  tmp$speed = tmp$SPEED
  
  # tracklines --------------------------------------------------------------
  
  # take important columns
  trk = tmp[,c('time','lat','lon', 'altitude','speed','date','yday', 'year',  'platform', 'name', 'id')]
  
  # re-order
  trk = trk[order(trk$time, decreasing = TRUE),]
  
  # simplify
  trk = subsample_gps(gps = trk)
  
  # combine all effort segments
  TRK[[i]] = trk
  
  # sightings ---------------------------------------------------------------
  
  # take only sightings
  sig = droplevels(tmp[which(as.character(tmp$SPCODE)!=""),])
  
  if(nrow(sig)>0){
    
    # get sighting number
    sig$number = sig$GROUP_SIZE
    
    # get score
    sig$score = NA
    sig$score[sig$ID_RELIABILITY>0] = 'sighted'
    
    # determine species
    sig$species = NA
    sig$SPCODE = toupper(as.character(sig$SPCODE))
    sig$species[sig$SPCODE == 'RIWH'] = 'right'
    sig$species[sig$SPCODE == 'HUWH'] = 'humpback'
    sig$species[sig$SPCODE == 'SEWH'] = 'sei'
    sig$species[sig$SPCODE == 'FIWH'] = 'fin'
    sig$species[sig$SPCODE == 'MIWH'] = 'minke'
    sig$species[sig$SPCODE == 'BLWH'] = 'blue'
    
    # drop unknown codes
    sig = sig[which(!is.na(sig$species)),]
    
    # right whale numbers
    eg = sig[sig$species=='right',]
    eg = eg[(!grepl('dup', eg$SIGHTING_COMMENTS) & 
               (grepl('ap',eg$SIGHTING_COMMENTS) | 
                  grepl('fin est no break', eg$SIGHTING_COMMENTS) | 
                  grepl('No right whales', eg$DateTime))),]
    
    # other whales
    noeg = sig[sig$species!='right',]
    
    # recombine all species
    sig = rbind.data.frame(eg,noeg)
    
    # keep important columns
    sig = sig[,cnames]
    
  } else {
    
    # make empty data frame
    sig = data.frame(matrix(ncol = length(cnames), nrow = 0))
    colnames(sig) = cnames
    
  }
  
  # add to the list
  SIG[[i]] = sig
  
}

# prep track output -------------------------------------------------------

# combine all tracks
tracks = bind_rows(TRK)

# config data types
tracks = config_tracks(tracks)

# save
saveRDS(tracks, paste0(output_dir, track_file))

# prep sightings output ---------------------------------------------------

# combine all sightings
sightings = bind_rows(SIG)

# config data types
sightings = config_observations(sightings)

# save
saveRDS(sightings, paste0(output_dir, sighting_file))
