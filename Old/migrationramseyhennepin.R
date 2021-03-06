library(dplyr)
library(readr)
library(purrr)
library(srvyr)

######################################
######### Migration to MN ############
######################################

#using srvyr
# inmigration <- read_csv("usa_00010.csv.gz") %>%
#   mutate(geogroup =ifelse(PUMARES2MIG==14, "Hennepin",
#                           ifelse(PUMARES2MIG==13, "Ramsey", "All Other Counties")),
#          agegroup = ifelse(AGE<17, "16 and Younger",
#                            ifelse(AGE>=17 & AGE<24, "17 to 23",
#                                   ifelse(AGE>=24 & AGE<31, "24 to 30", "31 and Over")
#                            )
#          ),
#          moved = ifelse(!(MIGPLAC1 %in% c(0,27)) & MIGPLAC1<150, 1, 0)
#   ) %>%
#       as_survey_design(weights=PERWT) %>%
#       group_by(geogroup, agegroup) %>%
#       summarise(moved_in = survey_total(moved)) 




#Verify that the srvyr match up with the R survey package
library(survey)
inmigration <- read_csv("usa_00010.csv.gz") %>%
  mutate(geogroup =ifelse(PUMARES2MIG==14, "Hennepin", 
                          ifelse(PUMARES2MIG==13, "Ramsey", "All Other Counties")),
         agegroup = ifelse(AGE<17, "16 and Younger",
                           ifelse(AGE>=17 & AGE<24, "17 to 23",
                                  ifelse(AGE>=24 & AGE<31, "24 to 30", "31 and Over")
                           )
         ),
         moved = ifelse(!(MIGPLAC1 %in% c(0,27)) & MIGPLAC1<150, 1, 0)
  )

inmigration <- svydesign(ids = ~1,
                              data= inmigration,
                              weights = inmigration$PERWT)


inmigration <- svyby(~moved, ~geogroup+agegroup, inmigration, svytotal)

inmigration <- cbind(inmigration, confint(inmigration, level = .9))
names(inmigration)[c(3:6)] <- c("moved_in","se_in","ci_low_in", "ci_high_in")


######################################
######### Migration from MN ##########
######################################

# outmigration <- read_csv("usa_00009.csv.gz") %>%
#       filter(STATEFIP != 27) %>%
#       mutate(geogroup =ifelse(MIGPUMA1==1400, "Hennepin", 
#                               ifelse(MIGPUMA1==1300, "Ramsey", "All Other Counties")),
#              agegroup = ifelse(AGE<17, "16 and Younger",
#                                ifelse(AGE>=17 & AGE<24, "17 to 23",
#                                       ifelse(AGE>=24 & AGE<31, "24 to 30", "31 and Over")
#                                )
#              )) %>%
#       as_survey_design(weights=PERWT)  %>%
#       group_by(geogroup, agegroup) %>%
#       summarise(moved_out = survey_total())


#Verify that the srvyr match up with the R survey package
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

outmigration <- svydesign(ids = ~1,
                                 data= outmigration,
                                 weights = outmigration$PERWT)

outmigration <- svyby(~one, ~geogroup+agegroup, outmigration, svytotal)
outmigration <- cbind(outmigration, confint(outmigration, level = .9))
names(outmigration)[c(3:6)] <- c("moved_out","se_out","ci_low_out", "ci_high_out")

######################################
######### Graph Net Migration ########
######################################
netmig <- left_join(inmigration, outmigration, by=c("agegroup","geogroup")) %>%
      mutate(net_migration = moved_in-moved_out )
write.csv(netmig, "netmigration.csv")

library(tidyr)
netmig_long <- left_join(inmigration, outmigration) %>%
      gather(direction, mig, moved_in, moved_out) %>%
      mutate(se = ifelse(direction=="moved_in", se_in, se_out),
             ci_low = ifelse(direction=="moved_in", ci_low_in, ci_low_out),
             ci_high = ifelse(direction=="moved_in", ci_high_in, ci_high_out)) %>%
      select(-se_out, -se_in, -ci_low_in, -ci_high_in, -ci_low_out, -ci_high_out) %>%
      mutate(geogroup = factor(geogroup, levels=c("Hennepin","Ramsey", "All Other Counties")),
             direction = factor(direction, levels=c("moved_out", "moved_in")))

library(ggplot2)
barplot17_totals <- filter(netmig_long, agegroup=="17 to 23") %>%
      ggplot(aes(x=geogroup, y=mig, fill=direction)) +
      geom_bar(stat="identity", position="dodge") +
      geom_text(aes(x=geogroup, y=mig, label=scales::comma(mig)),
                position=position_dodge(width=0.9), vjust=-0.25) +
      theme(
            panel.background = element_blank(),
            axis.ticks.x=element_blank(),
            axis.ticks.y=element_blank(),
            axis.title.x=element_blank(),
            axis.title.y=element_blank(),
            axis.text.x=element_text(size=10, color="black"),
            axis.text.y=element_blank(),
            legend.title=element_blank(),
            legend.position="bottom",
            plot.caption=element_text(size=8, hjust=.5),
            plot.title = element_text(hjust = 0.5)
      ) +
      scale_y_continuous(labels=scales::comma) +
      scale_fill_discrete(labels=c("Left MN for Another State", "Moved to MN from Another State")) +
      labs(title = "Average Annual Migration between Minnesota and Other States, 2011-2015\nPersons Aged 17 to 23",
           caption = "Source: House Research. 2015 American Community Survey 5-year Estimates. IPUMS-USA, University of Minnesota.") 

ggsave("ages17to23_totals.png", barplot17_totals,width=8,height=6) 

barplot17_errorbars <- filter(netmig_long, agegroup=="17 to 23") %>%
  ggplot(aes(x=geogroup, y=mig, fill=direction)) +
  geom_bar(stat="identity", position="dodge") +
  geom_errorbar(aes(ymin=ci_low, ymax=ci_high), 
                width = .2,
                position=position_dodge(.9)) +
  geom_text(aes(x=geogroup, y=mig, label=scales::comma(mig)),
            position=position_dodge(width=0.9), vjust=-2.5) +
  theme(
    panel.background = element_blank(),
    axis.ticks.x=element_blank(),
    axis.ticks.y=element_blank(),
    axis.title.x=element_blank(),
    axis.title.y=element_blank(),
    axis.text.x=element_text(size=10, color="black"),
    axis.text.y=element_blank(),
    legend.title=element_blank(),
    legend.position="bottom",
    plot.caption=element_text(size=8, hjust=.5),
    plot.title = element_text(hjust = 0.5)
  ) +
  scale_fill_discrete(labels=c("Left MN for Another State", "Moved to MN from Another State")) +
  labs(title = "Average Annual Migration between Minnesota and Other States, 2011-2015\nPersons Aged 17 to 23",
       caption = "Source: House Research. 2015 American Community Survey 5-year Estimates. IPUMS-USA, University of Minnesota.") 

ggsave("ages17to23_errorbars.png", barplot17_errorbars,width=8,height=6) 


barplot24 <- filter(netmig_long, agegroup=="24 to 30") %>%
      ggplot(aes(x=geogroup, y=mig, fill=direction)) +
      geom_bar(stat="identity", position="dodge") +
      geom_text(aes(x=geogroup, y=mig, label=scales::comma(mig)),
                position=position_dodge(width=0.9), vjust=-0.25) +
      theme(
            panel.background = element_blank(),
            axis.ticks.x=element_blank(),
            axis.ticks.y=element_blank(),
            axis.title.x=element_blank(),
            axis.title.y=element_blank(),
            axis.text.x=element_text(size=10, color="black"),
            axis.text.y=element_blank(),
            legend.title=element_blank(),
            legend.position="bottom",
            plot.caption=element_text(size=8, hjust=.5),
            plot.title = element_text(hjust = 0.5)
      ) +
      scale_fill_discrete(labels=c("Left MN for Another State", "Moved to MN from Another State")) +
      labs(title = "Average Annual Migration between Minnesota and Other States, 2011-2015\nPersons Aged 24 to 30",
           caption = "Source: House Research. 2015 American Community Survey 5-year Estimates. IPUMS-USA, University of Minnesota.") 

ggsave("ages24to30_totals.png", barplot24,width=8,height=6)

barplot24_errorbars <- filter(netmig_long, agegroup=="24 to 30") %>%
  ggplot(aes(x=geogroup, y=mig, fill=direction)) +
  geom_bar(stat="identity", position="dodge") +
  geom_errorbar(aes(ymin=ci_low, ymax=ci_high), 
                width = .2,
                position=position_dodge(.9))+
  geom_text(aes(x=geogroup, y=mig, label=scales::comma(mig)),
            position=position_dodge(width=0.9), vjust=-3.5) +
  theme(
    panel.background = element_blank(),
    axis.ticks.x=element_blank(),
    axis.ticks.y=element_blank(),
    axis.title.x=element_blank(),
    axis.title.y=element_blank(),
    axis.text.x=element_text(size=10, color="black"),
    axis.text.y=element_blank(),
    legend.title=element_blank(),
    legend.position="bottom",
    plot.caption=element_text(size=8, hjust=.5),
    plot.title = element_text(hjust = 0.5)
  ) +
  scale_y_continuous(labels=scales::comma) +
  scale_fill_discrete(labels=c("Left MN for Another State", "Moved to MN from Another State")) +
  labs(title = "Average Annual Migration between Minnesota and Other States, 2011-2015\nPersons Aged 24 to 30",
       caption = "Source: House Research. 2015 American Community Survey 5-year Estimates. IPUMS-USA, University of Minnesota.") 


ggsave("ages24to30_errorbars.png", barplot24_errorbars,width=8,height=6)
