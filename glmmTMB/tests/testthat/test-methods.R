stopifnot(require("testthat"),
          require("glmmTMB"))

data(sleepstudy, cbpp,
     package = "lme4")

if (getRversion() < "3.3.0") {
    sigma.default <- function (object, use.fallback = TRUE, ...) 
        sqrt(deviance(object, ...)/(nobs(object, use.fallback = use.fallback) - 
                                    length(coef(object))))
}

## FIXME: fit these centrally and restore, to save time
fm2   <- glmmTMB(Reaction ~ Days + (Days| Subject), sleepstudy)
fm2diag   <- glmmTMB(Reaction ~ Days + diag(Days| Subject), sleepstudy)
fm0   <- update(fm2, . ~ . -Days)
fm2P  <- update(fm2, round(Reaction) ~ ., family=poisson)
fm2G  <- update(fm2, family=Gamma(link="log"))
fm2NB <- update(fm2P, family=nbinom2)
## for testing sigma() against base R
fm3   <- update(fm2, . ~ Days)
fm3G <-  update(fm3, family=Gamma(link="log"))
fm3NB <- update(fm3, round(Reaction) ~ ., family=nbinom2)

context("basic methods")

test_that("Fitted and residuals", {
    expect_equal(length(fitted(fm2)),nrow(sleepstudy))
    expect_equal(mean(fitted(fm2)),298.507891)
    expect_equal(mean(residuals(fm2)),0,tol=1e-5)
    ## Pearson and response are the same for a Gaussian model
    expect_equal(residuals(fm2,type="response"),
                 residuals(fm2,type="pearson"))
    ## ... but not for Poisson or NB ...
    expect_false(mean(residuals(fm2P,type="response"))==
                 mean(residuals(fm2P,type="pearson")))
    expect_false(mean(residuals(fm2NB,type="response"))==
                 mean(residuals(fm2NB,type="pearson")))
    rr2 <- function(x) sum(residuals(x,type="pearson")^2)
    ## test Pearson resids for gaussian, Gamma vs. base-R versions
    ss <- as.data.frame(state.x77)
    expect_equal(rr2(glm(Murder~Population,ss,family=gaussian)),
          rr2(glmmTMB(Murder~Population,ss,family=gaussian)))
    expect_equal(rr2(glm(Murder~Population,ss,family=Gamma(link="log"))),
                 rr2(glmmTMB(Murder~scale(Population),ss,
                             family=Gamma(link="log"))),tol=1e-5)
    ## weights are incorporated in Pearson residuals
    ## GH 307
    tmbm4 <- glm(incidence/size ~ period,
             data = cbpp, family = binomial, weights = size)
    tmbm5 <- glmmTMB(incidence/size ~ period,
                     data = cbpp, family = binomial, weights = size)
    expect_equal(residuals(tmbm4,type="pearson"),
                 residuals(tmbm5,type="pearson"),tolerance=1e-6)
    ## two-column responses give vector of residuals GH 307
    tmbm6 <- glmmTMB(cbind(incidence,size-incidence) ~ period,
                     data = cbpp, family = binomial)
    expect_equal(residuals(tmbm4,type="pearson"),
                 residuals(tmbm6,type="pearson"),tolerance=1e-6)

})

test_that("Predict", {
    expect_equal(predict(fm2),predict(fm2,newdata=sleepstudy))
    pr2se <- predict(fm2, se.fit=TRUE)
    i <- sample(nrow(sleepstudy), 20)
    newdata <- sleepstudy[i, ]
    pr2sub <- predict(fm2, newdata=newdata, se.fit=TRUE)
    expect_equivalent(pr2se$fit, predict(fm2))
    expect_equivalent(pr2se$fit[i], pr2sub$fit)
    expect_equivalent(pr2se$se.fit[i], pr2sub$se.fit)
    expect_equal(unname( pr2se$   fit[1] ), 254.2208, tol=1e-4)
    expect_equal(unname( pr2se$se.fit[1] ), 12.94514, tol=1e-4)
    expect_equal(unname( pr2se$   fit[100] ), 457.9684, tol=1e-4)
    expect_equal(unname( pr2se$se.fit[100] ), 14.13943, tol=1e-4)

    ## predict without response in newdata
    expect_equal(predict(fm2),
                 predict(fm2,newdata=sleepstudy[,c("Days","Subject")]))
    
})


test_that("VarCorr", {
   vv <- VarCorr(fm2)
   vv2 <- vv$cond$Subject
   expect_equal(dim(vv2),c(2,2))
   expect_equal(outer(attr(vv2,"stddev"),
                      attr(vv2,"stddev"))*attr(vv2,"correlation"),
                vv2,check.attributes=FALSE)
   vvd <- VarCorr(fm2diag)
   expect_equal(vvd$cond$Subject[1,2],0) ## off-diagonal==0
})

test_that("drop1", {
      dd <- drop1(fm2,test="Chisq")
      expect_equal(dd$AIC,c(1763.94,1785.48),tol=1e-4)              
          })
test_that("anova", {
      aa <- anova(fm0,fm2)
      expect_equal(aa$AIC,c(1785.48,1763.94),tol=1e-4)
          })

test_that("terms", {
    ## test whether terms() are returned with predvars for doing
    ## model prediction etc. with complex bases
    dd <<- data.frame(x=1:10,y=1:10)
    require("splines")
    m <- glmmTMB(y~ns(x,3),dd)
    ## if predvars is not properly attached to term, this will
    ## fail as it tries to construct a 3-knot spline from a single point
    expect_equal(model.matrix(delete.response(terms(m)),data=data.frame(x=1)),
      structure(c(1, 0, 0, 0), .Dim = c(1L, 4L), .Dimnames = list("1", 
    c("(Intercept)", "ns(x, 3)1", "ns(x, 3)2", "ns(x, 3)3")),
    assign = c(0L, 1L, 1L, 1L)))
})

test_that("summary_print", {
    getVal <- function(x,tag="Dispersion") {
        cc <- capture.output(print(summary(x)))
        if (length(gg <- grep(tag,cc,value=TRUE))==0) return(NULL)
        cval <- sub("^.*: ","",gg) ## get value after colon ...
        return(as.numeric(cval))
    }
    ## no dispersion printed for Gaussian or disp==1 families
    expect_equal(getVal(fm2),654.9,tolerance=1e-2)
    expect_equal(getVal(fm2P),NULL)
    expect_equal(getVal(fm2G),0.00654,tolerance=1e-2)
    expect_equal(getVal(fm2NB,"Overdispersion"),286,tolerance=1e-2)
})

test_that("sigma", {
    s1 <<- sigma(lm(Reaction~Days,sleepstudy))
    s2 <<- sigma(glm(Reaction~Days,sleepstudy,family=Gamma(link="log")))
    s3 <<- MASS::glm.nb(round(Reaction)~Days,sleepstudy)
    ## remove bias-correction
    expect_equal(sigma(fm3),s1*(1-1/nobs(fm3)),tolerance=1e-3)
    expect_equal(sigma(fm3G),s2,tolerance=5e-3)
    expect_equal(s3$theta,sigma(fm3NB),tolerance=1e-4)
})

test_that("confint", {
    ci <- confint(fm2, 1:2, estimate=FALSE)
    expect_equal(ci,
        structure(c(238.406083254105, 7.52295734348693,
                    264.404107485727, 13.4116167530013),
                  .Dim = c(2L, 2L),
                  .Dimnames = list(c("cond.(Intercept)", "cond.Days"),
                                   c("2.5 %", "97.5 %"))),
        tolerance=1e-6)
    ciw <- confint(fm2, 1:2, method="Wald", estimate=FALSE)
    expect_warning(confint(fm2,type="junk"),
                   "extra arguments ignored")
    ## Gamma test Std.Dev and sigma
    ci <- confint(fm2G, estimate=FALSE)
    ci.expect <- structure(c(5.481017, 0.024778, 0.06761,  0.011595, 0.072046,
                             5.584018, 0.042922, 0.150456, 0.026438, 0.090737),
                           .Dim = c(5L,  2L),
                           .Dimnames = list(c("cond.(Intercept)", "cond.Days",
                                              "cond.Std.Dev.(Intercept)",
                                              "cond.Std.Dev.Days",
                                              "sigma"),
                                            c("2.5 %", "97.5 %")))
    expect_equal(ci, ci.expect, tolerance=1e-6)
    ## nbinom2 test Std.Dev and sigma
    ci <- confint(fm2NB, estimate=FALSE)
    ci.expect <- structure(c(5.480987, 0.024816, 0.066177, 0.011344, 183.810585,
                             5.584226, 0.042899, 0.150918, 0.026355, 444.735666),
                           .Dim = c(5L,  2L),
                           .Dimnames = list(c("cond.(Intercept)", "cond.Days",
                                              "cond.Std.Dev.(Intercept)",
                                              "cond.Std.Dev.Days", "sigma"),
                                            c("2.5 %", "97.5 %")))
    expect_equal(ci, ci.expect, tolerance=1e-6)
    ## profile CI
    ci.prof <- confint(fm2,parm=1,method="profile", npts=3)
    expect_equal(ci.prof,
                 structure(c(237.27249, 265.13383),
                           .Dim = 1:2, .Dimnames = list(
                                "(Intercept)", c("2.5 %", "97.5 %"))),
                 tolerance=1e-6)
    ## uniroot CI
    ci.uni <- confint(fm2,parm=1,method="uniroot")
    expect_equal(ci.uni,
                 structure(c(237.68071,265.12949,251.4050979),
                        .Dim = c(1L, 3L),
        .Dimnames = list("(Intercept)", c("2.5 %", "97.5 %", "Estimate"))),
                 tolerance=1e-6)
    ## check against 'raw' tmbroot
    ## (not exported (yet?) ...)
    ## tmbr <- glmmTMB:::tmbroot(fm2$obj,name=1)
})

test_that("vcov", {
    expect_equal(dim(vcov(fm2)[[1]]),c(2,2))
    expect_equal(dim(vcov(fm2,full=TRUE)),c(6,6))
    expect_equal(rownames(vcov(fm2,full=TRUE)),
           structure(c("(Intercept)", "Days", "d~(Intercept)",
                       "theta_Days|Subject.1", "theta_Days|Subject.2",
                       "theta_Days|Subject.3"),
          .Names = c("cond1", "cond2", "disp", "", "", "")))
    ## vcov doesn't include dispersion for non-dispersion families ...
    expect_equal(dim(vcov(fm2P,full=TRUE)),c(5,5))
})

set.seed(101)
test_that("simulate", {
    sm2 <<- rowMeans(do.call(cbind, simulate(fm2, 10)))
    sm2P <<- rowMeans(do.call(cbind, simulate(fm2P, 10)))
    sm2G <<- rowMeans(do.call(cbind, simulate(fm2G, 10)))
    sm2NB <<- rowMeans(do.call(cbind, simulate(fm2NB, 10)))
    expect_equal(sm2, sleepstudy$Reaction, tol=20)
	expect_equal(sm2P, sleepstudy$Reaction, tol=20)
	expect_equal(sm2G, sleepstudy$Reaction, tol=20)
	expect_equal(sm2NB, sleepstudy$Reaction, tol=20)
})

context("simulate consistency with glm/lm")
test_that("binomial", {
    y <- cbind(1:10,10)
    f1 <- glmmTMB(y ~ 1, family=binomial())
    f2 <- glm    (y ~ 1, family=binomial())
    set.seed(1)
    s1 <- simulate(f1, 5)
    set.seed(1)
    s2 <- simulate(f2, 5)
    expect_equal(max(abs(as.matrix(s1) - as.matrix(s2))), 0)
})
