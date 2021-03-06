library(ggeffects)
library(ggplot2)
library(coefplot)
library(cowplot)
library(effects)

# Read data
# start with the same data file that is used for analysis of survival/mortality
grdata <- read.csv("./Processed/Survival/SurvivalData.csv", header = T, stringsAsFactors = F)

# Only keep trees that didn't die
grdata <- subset(grdata, STATUSCD == 1) #18204

# Create increment columns
# note that growth increments need to be moved to the positive realm (by adding a constant)
# IF log transform is used
grdata$AGB_INCR <- grdata$DRYBIO_AG_DIFF / grdata$CENSUS_INTERVAL
grdata$DIA_INCR <- grdata$DIA_DIFF / grdata$CENSUS_INTERVAL
grdata$BA_INCR <- grdata$BA_DIFF / grdata$CENSUS_INTERVAL

# distribution of size
#hist(grdata$BAt1) # size is lognormal-ish, with a wonky bit at the small end of the scale (due to min size threshold?)
#hist(grdata$BAt1, breaks = c(seq(0, 1220, by = 10)), xlim = c(0, 500))
#hist(log(grdata$BAt1)) # not quite lognormal, but worth trying in the models below (heavy in the left tail)
hist(grdata$PREVDIA)

# distribution of other predictors
hist(grdata$PPT_yr) # not too bad...Poisson-ish but with a large mean count
hist(log(grdata$PPT_yr)) # more normal-looking
hist(grdata$T_yr) # looks normal
hist(grdata$BALIVE) # not too bad...Poisson-ish but with a large mean count
hist(log(grdata$BALIVE)) # log transform has a heavy left tail

# examine distribution of response(s)
#hist(grdata$AGB_INCR)
#hist(grdata$AGB_INCR, breaks = c(seq(-106, 165, by = 0.5)), xlim = c(-10, 15))
hist(grdata$DIA_INCR)
summary(grdata$DIA_INCR)
hist(grdata$DIA_INCR, breaks = c(seq(-2.5, 1.75, by = 0.01)), xlim = c(-0.5, 0.5))

# standardize covariates
library(dplyr)
grdata.scaled <- grdata %>% mutate_at(scale, .vars = vars(-CN, -PREV_TRE_CN, -PLT_CN, -PREV_PLT_CN, -CONDID,
                                                    -STATUSCD, -MEASYEAR, -PREV_MEASYEAR, 
                                                    -CENSUS_INTERVAL,
                                                    -AGB_INCR, -DIA_INCR, -BA_INCR))


library(lme4)
library(lmerTest)
library(MuMIn) # use MuMin to choose between models (AICc)
library(DHARMa) # use DHARMa to check residuals

# compare different response variables
# DIA, AGB, BA
gmodel.AGB <- lmer(AGB_INCR ~ PREV_DRYBIO_AG + I(PREV_DRYBIO_AG^2) + BALIVE + PPT_c + PPT_wd + PPT_m + VPD_c + VPD_wd + VPD_m + (1|PLT_CN), data = grdata.scaled)
gmodel.DIA <- lmer(DIA_INCR ~ PREVDIA + I(PREVDIA^2) + BALIVE + PPT_c + PPT_wd + PPT_m + VPD_c + VPD_wd + VPD_m + (1|PLT_CN), data = grdata.scaled)
gmodel.BA <- lmer(BA_INCR ~ BAt1 + I(BAt1^2) + BALIVE + PPT_c + PPT_wd + PPT_m + VPD_c + VPD_wd + VPD_m + (1|PLT_CN), data = grdata.scaled)
mod.comp <- model.sel(gmodel.AGB, gmodel.DIA, gmodel.BA)

# check residuals
class(gmodel.AGB) <- "lmerMod"
plot(simulateResiduals(gmodel.AGB, integerResponse = F), quantreg = T)
plot(gmodel.AGB)

class(gmodel.DIA) <- "lmerMod"
plot(simulateResiduals(gmodel.DIA, integerResponse = F), quantreg = T)
plot(gmodel.DIA)

class(gmodel.BA) <- "lmerMod"
plot(simulateResiduals(gmodel.BA, integerResponse = F), quantreg = T)
plot(gmodel.BA)

### LISA: only the residuals of the DIA model look more or less acceptable, for BA and AGB we would require a non-linear model, I suppose. 

gmodel.1a <- lmer(DIA_INCR ~ BAt1 + I(BAt1^2) + BALIVE + PPT_yr + VPD_yr + (1|PLT_CN), data = grdata.scaled)
gmodel.1b <- lmer(DIA_INCR ~ PREVDIA + I(PREVDIA^2) + BALIVE + PPT_yr + VPD_yr + (1|PLT_CN), data = grdata.scaled)
gmodel.1c <- lmer(DIA_INCR ~ PREV_DRYBIO_AG + I(PREV_DRYBIO_AG^2) + BALIVE + PPT_yr + VPD_yr + (1|PLT_CN), data = grdata.scaled)

class(gmodel.1a) <- "lmerMod"
plot(simulateResiduals(gmodel.1a, integerResponse = F), quantreg = T)

# residuals looks good for model using PREVDIA as a (size) predictor
class(gmodel.1b) <- "lmerMod"
plot(simulateResiduals(gmodel.1b, integerResponse = F), quantreg = T)

# demonstrate effect of quadratics
gmodel.lin <- lmer(DIA_INCR ~ PREVDIA + BALIVE + PPT_yr_norm + T_yr_norm + 
                    (1|PLT_CN), data = grdata.scaled)
gmodel.q <- lmer(DIA_INCR ~ PREVDIA + BALIVE + PPT_yr_norm + T_yr_norm + 
                   I(PREVDIA^2) + I(BALIVE^2) + I(PPT_yr_norm^2) + I(T_yr_norm^2) + 
                     (1|PLT_CN), data = grdata.scaled)
mod.comp0<-model.sel(gmodel.lin,gmodel.q)
# strong preference for quadratics (delta AIC = 76.24)

# compare T vs. VPD... delta AIC is 4.78 (preference for T)
gmodel.1a <- lmer(DIA_INCR ~ PREVDIA + BALIVE + PPT_yr + VPD_yr + I(PREVDIA^2) + I(BALIVE^2) + 
                    I(PPT_yr^2) + I(VPD_yr^2) + 
                    (1|PLT_CN), data = grdata.scaled)
gmodel.1b <- lmer(DIA_INCR ~ PREVDIA + BALIVE + PPT_yr + T_yr + I(PREVDIA^2) + I(BALIVE^2) + 
                    I(PPT_yr^2) + I(T_yr^2) + 
                    (1|PLT_CN), data = grdata.scaled)
mod.comp1 <- model.sel(gmodel.1a, gmodel.1b)

# compare annual vs. 3 vs. 4 seasons...likes annual better 
gmodel.2a <- lmer(DIA_INCR ~ PREVDIA + BALIVE + PPT_c + PPT_wd + PPT_m + T_c + T_wd + T_m + 
                  I(PREVDIA^2) + I(BALIVE^2) + I(PPT_c^2) + I(PPT_wd^2) + I(PPT_m^2) + 
                  I(T_c^2) + I(T_wd^2) + (T_m^2) + 
                  (1|PLT_CN), data = grdata.scaled)
gmodel.2b <- lmer(DIA_INCR ~ PREVDIA + BALIVE + PPT_c + + PPT_pf + PPT_fs + PPT_m + T_c + T_pf + T_fs + T_m + 
                    I(PREVDIA^2) + I(BALIVE^2) + I(PPT_c^2) + I(PPT_pf^2) + I(PPT_fs^2) + I(PPT_m^2) + 
                    I(T_c^2) + I(T_pf^2) + I(T_fs^2) + (T_m^2) + 
                    (1|PLT_CN), data = grdata.scaled)
mod.comp2 <- model.sel(gmodel.1b, gmodel.2a, gmodel.2b)

# compare normals vs. census interval vs. anomalies...census interval is best
gmodel.3a <- lmer(DIA_INCR ~ PREVDIA + BALIVE + PPT_yr_norm + T_yr_norm + I(PREVDIA^2) + I(BALIVE^2) + 
                    I(PPT_yr_norm^2) + I(T_yr_norm^2) + 
                    (1|PLT_CN), data = grdata.scaled)
gmodel.3b <- lmer(DIA_INCR ~ PREVDIA + BALIVE + PPT_c_norm + PPT_wd_norm + PPT_m_norm + 
                    T_c_norm + T_wd_norm + T_m_norm + I(PREVDIA^2) + I(BALIVE^2) + 
                    I(PPT_c_norm^2) + I(PPT_wd_norm^2) + I(PPT_m_norm^2) + 
                    I(T_c_norm^2) + I(T_wd_norm^2) + (T_m_norm^2) + 
                    (1|PLT_CN), data = grdata.scaled)
gmodel.3c <- lmer(DIA_INCR ~ PREVDIA + BALIVE + PPT_yr_anom + T_yr_anom + I(PREVDIA^2) + I(BALIVE^2) + 
                    I(PPT_yr_anom^2) + I(T_yr_anom^2) + 
                    (1|PLT_CN), data = grdata.scaled)
gmodel.3d <- lmer(DIA_INCR ~ PREVDIA + BALIVE + PPT_c_anom + PPT_wd_anom + PPT_m_anom + 
                    T_c_anom + T_wd_anom + T_m_anom + I(PREVDIA^2) + I(BALIVE^2) + 
                    I(PPT_c_anom^2) + I(PPT_wd_anom^2) + I(PPT_m_anom^2) + 
                    I(T_c_anom^2) + I(T_wd_anom^2) + (T_m_anom^2) + 
                    (1|PLT_CN), data = grdata.scaled)
gmodel.3e <- lmer(DIA_INCR ~ PREVDIA + BALIVE + PPT_yr_anom + T_yr_anom + PPT_yr_norm + T_yr_norm + 
                    I(PREVDIA^2) + I(BALIVE^2) + 
                    I(PPT_yr_anom^2) + I(T_yr_anom^2) + I(PPT_yr_norm^2) + I(T_yr_norm^2) + 
                    (1|PLT_CN), data = grdata.scaled)
gmodel.3f <- lmer(DIA_INCR ~ PREVDIA + BALIVE + PPT_c_norm + PPT_wd_norm + PPT_m_norm + 
                    T_c_norm + T_wd_norm + T_m_norm + I(PREVDIA^2) + I(BALIVE^2) + 
                    I(PPT_c_norm^2) + I(PPT_wd_norm^2) + I(PPT_m_norm^2) + 
                    I(T_c_norm^2) + I(T_wd_norm^2) + (T_m_norm^2) + 
                    PPT_c_anom + PPT_wd_anom + PPT_m_anom + 
                    T_c_anom + T_wd_anom + T_m_anom + 
                    I(PPT_c_anom^2) + I(PPT_wd_anom^2) + I(PPT_m_anom^2) + 
                    I(T_c_anom^2) + I(T_wd_anom^2) + (T_m_anom^2) + 
                    (1|PLT_CN), data = grdata.scaled)
gmodel.3g <- lmer(DIA_INCR ~ PREVDIA + BALIVE + PPTex_yr_anom + Tex_yr_anom + I(PREVDIA^2) + I(BALIVE^2) + 
                    I(PPTex_yr_anom^2) + I(Tex_yr_anom^2) + 
                    (1|PLT_CN), data = grdata.scaled)
gmodel.3h <- lmer(DIA_INCR ~ PREVDIA + BALIVE + PPTex_c_anom + PPTex_wd_anom + PPTex_m_anom + 
                     Tex_c_anom + Tex_wd_anom + Tex_m_anom + I(PREVDIA^2) + I(BALIVE^2) + 
                     I(PPTex_c_anom^2) + I(PPTex_wd_anom^2) + I(PPTex_m_anom^2) + 
                     I(Tex_c_anom^2) + I(Tex_wd_anom^2) + (Tex_m_anom^2) + 
                     (1|PLT_CN), data = grdata.scaled)
gmodel.3i <- lmer(DIA_INCR ~ PREVDIA + BALIVE + PPT_yr_norm + T_yr_norm + I(PREVDIA^2) + I(BALIVE^2) + 
                    I(PPT_yr_norm^2) + I(T_yr_norm^2) + PPTex_yr_anom + Tex_yr_anom + 
                    I(PPTex_yr_anom^2) + I(Tex_yr_anom^2) + 
                    (1|PLT_CN), data = grdata.scaled)
gmodel.3j <- lmer(DIA_INCR ~ PREVDIA + BALIVE + PPT_c_norm + PPT_wd_norm + PPT_m_norm + 
                    T_c_norm + T_wd_norm + T_m_norm + I(PREVDIA^2) + I(BALIVE^2) + 
                    I(PPT_c_norm^2) + I(PPT_wd_norm^2) + I(PPT_m_norm^2) + 
                    I(T_c_norm^2) + I(T_wd_norm^2) + (T_m_norm^2) + 
                    PPTex_c_anom + PPTex_wd_anom + PPTex_m_anom + 
                    Tex_c_anom + Tex_wd_anom + Tex_m_anom + 
                    I(PPTex_c_anom^2) + I(PPTex_wd_anom^2) + I(PPTex_m_anom^2) + 
                    I(Tex_c_anom^2) + I(Tex_wd_anom^2) + (Tex_m_anom^2) + 
                    (1|PLT_CN), data = grdata.scaled)

mod.comp3 <- model.sel(gmodel.1b, gmodel.3a, gmodel.3b, gmodel.3c, gmodel.3d, gmodel.3e, gmodel.3f, 
                       gmodel.3g, gmodel.3h, gmodel.3i, gmodel.3j)
# gmodel.1b is best among these 

# add drought anomalies
gmodel.4a<- lmer(DIA_INCR ~ PREVDIA + BALIVE + PPT_yr + T_yr + PPT_drought + Tmean_drought + 
                               I(PREVDIA^2) + I(BALIVE^2) + 
                               I(PPT_yr^2) + I(T_yr^2) + I(PPT_drought^2) + I(Tmean_drought^2) + 
                               (1|PLT_CN), data = grdata.scaled)
gmodel.4b<- lmer(DIA_INCR ~ PREVDIA + BALIVE + PPT_yr + T_yr + 
                               PPT_pf_dr + PPT_c_dr + PPT_fs_dr + PPT_m_dr + Tmean_drought + 
                               I(PREVDIA^2) + I(BALIVE^2) + I(PPT_yr^2) + I(T_yr^2) + 
                   I(PPT_pf_dr_anom^2) + I(PPT_c_dr^2) + I(PPT_fs_dr^2) + I(PPT_m_dr^2) + I(Tmean_drought^2) + 
                               (1|PLT_CN), data = grdata.scaled)
gmodel.4c<- lmer(DIA_INCR ~ PREVDIA + BALIVE + PPT_yr + T_yr + PPT_dr_anom + T_dr_anom + 
                   I(PREVDIA^2) + I(BALIVE^2) + 
                   I(PPT_yr^2) + I(T_yr^2) + I(PPT_dr_anom^2) + I(T_dr_anom^2) + 
                   (1|PLT_CN), data = grdata.scaled)
gmodel.4d<- lmer(DIA_INCR ~ PREVDIA + BALIVE + PPT_yr + T_yr + 
                   PPT_pf_dr_anom + PPT_c_dr_anom + PPT_fs_dr_anom + PPT_m_dr_anom + T_dr_anom + 
                   I(PREVDIA^2) + I(BALIVE^2) + I(PPT_yr^2) + I(T_yr^2) + 
                   I(PPT_pf_dr_anom^2) + I(PPT_c_dr_anom^2) + I(PPT_fs_dr_anom^2) + I(PPT_m_dr_anom^2) + I(T_dr_anom^2) + 
                   (1|PLT_CN), data = grdata.scaled)
mod.comp4<-model.sel(gmodel.1b,gmodel.4a,gmodel.4b,gmodel.4c,gmodel.4d)
# gmodel.1b is still best

# add 2-way interactions, excluding quadratics
gmodel.5a <- lmer(DIA_INCR ~ (PREVDIA + BALIVE + PPT_yr + T_yr)^2 + 
                    (1|PLT_CN), data = grdata.scaled)
gmodel.5b <- lmer(DIA_INCR ~ (PREVDIA + BALIVE + PPT_yr + T_yr)^2 + I(PREVDIA^2) + I(BALIVE^2) + 
                    I(PPT_yr^2) + I(T_yr^2) + 
                    (1|PLT_CN), data = grdata.scaled)
mod.comp5 <- model.sel(gmodel.1b, gmodel.5a, gmodel.5b)
# gmodel.1b is still best

class(gmodel.1b) <- "lmerMod"
plot(simulateResiduals(gmodel.3a, integerResponse = F), quantreg = T) # residuals look good


### Models to export
gmodel.clim <- lmer(DIA_INCR ~ PREVDIA + PPT_yr_norm + T_yr_norm + I(PREVDIA^2) + 
                      I(PPT_yr_norm^2) + I(T_yr_norm^2) + 
                      (1|PLT_CN), data = grdata.scaled)
gmodel.clim.comp <- lmer(DIA_INCR ~ PREVDIA + BALIVE + PPT_yr_norm + T_yr_norm + I(PREVDIA^2) + 
                           I(BALIVE^2) + I(PPT_yr_norm^2) + I(T_yr_norm^2) + 
                           (1|PLT_CN), data = grdata.scaled)
gmodel.int <- lmer(DIA_INCR ~ (PREVDIA + BALIVE + PPT_yr_norm + T_yr_norm)^2 + I(PREVDIA^2) + 
                     I(BALIVE^2) + I(PPT_yr_norm^2) + I(T_yr_norm^2) + 
                     (1|PLT_CN), data = grdata.scaled)
gmodel.best<- lmer(DIA_INCR ~ PREVDIA + BALIVE + PPT_yr + T_yr + I(PREVDIA^2) + I(BALIVE^2) + 
                     I(PPT_yr^2) + I(T_yr^2) + 
                     (1|PLT_CN), data = grdata.scaled)

gmodel.clim.lin <- lmer(DIA_INCR ~ PREVDIA + PPT_yr_norm + T_yr_norm + 
                      (1|PLT_CN), data = grdata.scaled)
gmodel.clim.comp.lin <- lmer(DIA_INCR ~ PREVDIA + BALIVE + PPT_yr_norm + T_yr_norm + 
                           (1|PLT_CN), data = grdata.scaled)
gmodel.int.lin <- lmer(DIA_INCR ~ (PREVDIA + BALIVE + PPT_yr_norm + T_yr_norm)^2 + 
                     (1|PLT_CN), data = grdata.scaled)

# growSD is used for building IPM (see BuildIPM.R)
growSD.clim <- sd(resid(gmodel.clim))
growSD.clim.comp <- sd(resid(gmodel.clim.comp))
growSD.int <- sd(resid(gmodel.int))
growSD.best <- sd(resid(gmodel.best))

growSD.clim.lin <- sd(resid(gmodel.clim.lin))
growSD.clim.comp.lin <- sd(resid(gmodel.clim.comp.lin))
growSD.int.lin <- sd(resid(gmodel.int.lin))

### dealing with std'ized covariates

# specify the predictors in the exported models
gr.predictors <- c("PREVDIA", "T_yr", "PPT_yr", "T_yr_norm", "PPT_yr_norm", "BALIVE") 
# eventually rewrite this so that it can handle alternative "best" models

get_scale = function(data, predictors) {
  sc = list("scale" = NULL, "center"  = NULL)
  for (i in predictors) {
    sc$scale[i] = attributes(data[, i])$"scaled:scale"
    sc$center[i] = attributes(data[, i])$"scaled:center"
  }
  return(sc)
}

gr.scaling = get_scale(grdata.scaled, gr.predictors)

# remove scaling information from the dataset so that the model doesnt expect scaled data in predict()
for (i in gr.predictors) {
  attributes(grdata.scaled[, i]) = NULL
}

# export model for coefficients and scaling information -------------------
#save(gmodel.7, gr.scaling, growSD, file = "./Code/IPM/GrRescaling.Rdata")
save(gmodel.clim,gmodel.clim.comp,gmodel.int,gmodel.best, 
     gmodel.clim.lin,gmodel.clim.comp.lin,gmodel.int.lin, 
     growSD.clim,growSD.clim.comp,growSD.int,growSD.best, 
     growSD.clim.lin,growSD.clim.comp.lin,growSD.int.lin, 
     gr.scaling, file = "./Code/IPM/GrRescaling.Rdata")
