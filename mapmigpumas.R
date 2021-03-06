library(dplyr)
library(readr)
library(purrr)
library(srvyr)


######################################
######## Run Analysis on Mig #########
######################################

migpumacrosswalk <- read_csv("./crosswalk/mnpumamigpuma11to15.csv") 
names(migpumacrosswalk)[3] <- "Res_MIGPUMA"


inmigration <- read_csv("usa_00011.csv.gz") %>%
  left_join(migpumacrosswalk, by=c("PUMA"="PUMA", "MULTYEAR"="Year")) %>%
  mutate(geogroup =ifelse(Res_MIGPUMA==14, "Hennepin", 
                          ifelse(Res_MIGPUMA==1300, "Ramsey", "All Other Counties")),
         agegroup = ifelse(AGE<17, "16 and Younger",
                           ifelse(AGE>=17 & AGE<24, "17 to 23",
                                  ifelse(AGE>=24 & AGE<31, "24 to 30", "31 and Over")
                           )
         ),
         moved = ifelse(!(MIGPLAC1 %in% c(0,27) & MIGPLAC1<100), 1, 0) 
  ) %>%
  as_survey_design(weights=PERWT) %>%
  group_by(Res_MIGPUMA, agegroup) %>%
  summarise(moved_in = survey_total(moved))

names(inmigration)[1] <- "migpuma"

library(survey)
outmigration <- read_csv("usa_00009.csv.gz") %>%
  filter(STATEFIP != 27) %>%
  mutate(geogroup =ifelse(MIGPUMA1==1400, "Hennepin", 
                          ifelse(MIGPUMA1==1300, "Ramsey", "All Other Counties")),
         agegroup = ifelse(AGE<17, "16 and Younger",
                           ifelse(AGE>=17 & AGE<24, "17 to 23",
                                  ifelse(AGE>=24 & AGE<31, "24 to 30", "31 and Over")
                           )
         ),
         one=1) 

outmigration_survey <- svydesign(ids = ~1,
                                  data= outmigration,
                                  weights = outmigration$PERWT)

outmigration <- svyby(~one, ~MIGPUMA1+agegroup, outmigration_survey, svytotal) %>%
  mutate(migpuma=MIGPUMA1,
         moved_out=one)

netmig <- left_join(outmigration, inmigration) %>%
  mutate(net_migration = moved_in-moved_out,
         id=MIGPUMA1)

######################################
######### Map Net Migration ##########
######################################

#load packages to use
library(rgdal)
library(ggplot2)
library(broom)
library(maptools)
library(rgeos)

#Read in shapefile for MigPumas
if (!file.exists("./caches/shapefile.rda")) {
  shapefile <- readOGR("./shapefile", "ipums_migpuma_pwpuma_2010")
  shapefile <- shapefile[shapefile@data$STATEFIP=="27",]
  save(shapefile, file="shapefile.rda")
} else {
  load("./caches/shapefile.rda")
}

mnmap <- tidy(shapefile, region="PWPUMA") %>%
  mutate(id=as.numeric(id)) %>%
  left_join(filter(netmig, agegroup=="24 to 30"))

ggplot() + 
  geom_polygon(data=mnmap,
               aes(long, lat, group=group, fill=net_migration),
               color="black") +
  coord_equal()