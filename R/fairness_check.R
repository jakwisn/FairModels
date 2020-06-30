#' Fairness check
#'
#' @description Fairness check creates fairness object which measures different fairness metrics and wraps data, explainers and parameters in useful object. This is fundamental object in this package
#' It allows to visualize fairness metrics in many ways and compare models on both fairness and performance level. Fairness check acts as merger and wrapper for explainers and fairness objects.
#' While other fairness objects values are not changed, fairness check assigns cutoffs and labels to provided explainers so same explainers with changed labels/cutoffs might be gradually added to fairness object.
#' Users through print and plot methods may quickly check values of most popular fairness metrics. More on that topic in details/
#'
#' @param x \code{DALEX explainer}/\code{fairness_object}
#' @param ... possibly more \code{DALEX explainers}/\code{fairness_objects}
#' @param protected vector, protected variable (also called sensitive attribute), containing privileged and unprivileged groups
#' @param privileged one value of \code{protected}, in regard to what subgroup parity loss is calculated
#' @param cutoff numeric, vector of cutoffs (thresholds) for each value of protected variable, affecting only explainers.
#' @param label character, vector of labels to be assigned for explainers, default is explainer label.
#' @param epsilon numeric, boundary for fairness checking
#' @param verbose logical, whether to print information about creation of fairness object
#' @param colorize logical, whether to print information in color
#'
#' @details Metrics used are made for each subgroup, then base metric score is subtracted leaving loss of particular metric.
#' If absolute loss is greater than epsilon than such metric is marked as "not passed". It means that values of metrics should be within (-epsilon,epsilon) boundary.
#' Epsilon value can be adjusted to user's needs. There are some metrics that might be derived from existing metrics (For example Equalized Odds - equal TPR and FPR for all subgroups).
#' That means passing 5 metrics in fairness check asserts that model is even more fair. In \code{fairness_check} models must always predict positive result. Not adhering to this rule
#' may lead to misinterpretation of the plot. More on metrics and their equivalents:
#' \url{https://fairware.cs.umass.edu/papers/Verma.pdf}
#' \url{https://en.wikipedia.org/wiki/Fairness_(machine_learning)}
#'
#'
#' @return An object of class \code{fairness_object} which is a list with elements:
#' \itemize{
#' \item metric_data - data.frame containing parity loss for various fairness metrics. Created with following metrics:
#' \itemize{
#'
#' \item TPR - True Positive Rate (Sensitivity, Recall, Equal Odds)
#' \item TNR - True Negative Rate (Specificity)
#' \item PPV - Positive Predictive Value (Precision)
#' \item NPV - Negative Predictive Value
#' \item FNR - False Negative Rate
#' \item FPR - False Positive Rate
#' \item FDR - False Discovery Rate
#' \item FOR - False Omission Rate
#' \item TS  - Threat Score
#' \item STP - Statistical Parity
#' \item ACC - Accuracy
#' \item F1  - F1 Score
#' \item MCC - Matthews correlation coefficient
#' }
#'
#' M_parity_loss = sum(abs(metric - base_metric))
#'
#' where:
#'
#' M - some metric mentioned above
#'
#' metric - vector of metrics from each subgroup
#'
#' base_metric - scalar, value of metric for base subgroup
#'
#' \item groups_data - metrics across levels in protected variable
#'
#' \item explainers  - list of DALEX explainers used to create object
#'
#' \item ...         - other parameters passed to function
#' }
#'
#' @references
#' Zafar,Valera, Rodriguez, Gummadi (2017)  \url{https://arxiv.org/pdf/1610.08452.pdf}
#'
#' Hardt, Price, Srebro (2016) \url{https://arxiv.org/pdf/1610.02413.pdf}
#'
#' Verma, Rubin (2018) \url{https://fairware.cs.umass.edu/papers/Verma.pdf}
#'
#'
#' @export
#' @rdname fairness_check
#'
#' @examples
#' data("german")
#'
#' y_numeric <- as.numeric(german$Risk) -1
#'
#' lm_model <- glm(Risk~.,
#'                 data = german,
#'                 family=binomial(link="logit"))
#'
#' rf_model <- ranger::ranger(Risk ~.,
#'                            data = german,
#'                            probability = TRUE,
#'                            num.trees = 200)
#'
#' explainer_lm <- DALEX::explain(lm_model, data = german[,-1], y = y_numeric)
#' explainer_rf <- DALEX::explain(rf_model, data = german[,-1], y = y_numeric)
#'
#' fobject <- fairness_check(explainer_lm, explainer_rf,
#'                           protected = german$Sex,
#'                           privileged = "male")
#'
#' plot(fobject)
#'


fairness_check <- function(x,
                           ...,
                           protected,
                           privileged,
                           cutoff = NULL,
                           label = NULL,
                           epsilon = NULL,
                           verbose = TRUE,
                           colorize = TRUE){

  if (!colorize) {
    color_codes <- list(yellow_start = "", yellow_end = "",
                        red_start = "", red_end = "",
                        green_start = "", green_end = "")
  }

  verbose_cat("Creating fairness object\n")

  verbose_cat("-> Privileged subgroup\t\t: ")

  # if protected and privileged are not characters, changing them
  verbose_cat(class(privileged), "(")
  if (is.character(privileged)){
    verbose_cat(color_codes$green_start,
        "Ok", color_codes$green_end, ")\n")
  } else {

    verbose_cat(color_codes$yellow_start,
        "changed to character",  color_codes$yellow_end, ")\n")
  }

  verbose_cat("-> Protected varaible\t\t:", class(protected), "(")

  if (is.factor(protected)){
    verbose_cat(color_codes$green_start,
        "Ok", color_codes$green_end, ") \n")
  } else {
    protected <- as.factor(protected)

    # if different cutoffs were provided print info in red
    if (length(unique(cutoff)) <= 1){
      verbose_cat(color_codes$yellow_start,
          "changed to factor", color_codes$yellow_end, ")\n")
    } else
    verbose_cat(color_codes$red_start,
        "changed to factor, check if levels match cutoff values ", color_codes$red_end, ")\n")
  }

  ################  data extraction  ###############

  list_of_objects   <- list(x,...)
  explainers        <- get_objects(list_of_objects, "explainer")
  fobjects          <- get_objects(list_of_objects, "fairness_object")

  explainers_from_fobjects <- sapply(fobjects, function(x) x$explainers)
  all_explainers           <- append(explainers, explainers_from_fobjects)

  fobjects_metric_data <- extract_data(fobjects, "metric_data")
  fobjects_groups_data <- extract_data(fobjects, "groups_data")
  fobjects_fcheck_data <- extract_data(fobjects, "fairness_check_data")
  fobjects_label       <- sapply(fobjects, function(x) x$label)
  fobjects_cuttofs     <- extract_data(fobjects, "cutoff")
  n_exp                <- length(explainers)

  ###############  error handling  ###############

  if (! privileged %in% protected){
   stop("privileged subgroup is not in protected variable vector")
  }

  if(is.null(epsilon)) epsilon <- 0.1

  if(! is.numeric(epsilon) | length(epsilon) > 1){
   stop("Epsilon must be single, numeric value")
  }

  # among all fairness_objects parameters should be equal
  verbose_cat("-> Fairness objects\t\t: ")

  for (i in seq_along(fobjects)){
    if(! all(fobjects[[i]]$protected  == protected)){
       verbose_cat(color_codes$red_start, "not compatible" ,color_codes$red_end, "\n")
       stop("fairness objects must have the same
            protected vector as one passed in fairness check")
    }
    if(! fobjects[[i]]$privileged == privileged) {
      verbose_cat(color_codes$red_start, "not compatible" ,color_codes$red_end, "\n")
      stop("fairness objects must have the same
           privlieged argument as one passed in fairness check")
    }}

  verbose_cat("compatible\n")


  # explainers must have equal y
  verbose_cat("-> Checking explainers\t\t:")
  y_to_compare <- all_explainers[[1]]$y
  for (exp in all_explainers){
    if(length(y_to_compare) != length(exp$y)){
      verbose_cat(color_codes$red_start, "not equal", color_codes$red_end, "\n")
      stop("All explainer predictions (y) must have same length")
    }
    if(! all(y_to_compare == exp$y)){
      verbose_cat(color_codes$red_start, "not equal", color_codes$red_end, "\n")
      stop("All explainers must have same values of target variable")
    }
  }
  verbose_cat("compatible\n")

  if (is.null(label)){
    label     <- sapply(explainers, function(x) x$label)
  } else {
    if (length(label) != n_exp) stop("Number of labels must be equal
                                     to number of explainers")
  }

  # explainers must have unique labels
  if (length(unique(label)) != length(label) ){
   stop("Explainers don't have unique labels
        (use 'label' parameter while creating dalex explainer)")
  }

  # labels must be unique for all explainers, those in fairness objects too
  if (any(label %in% fobjects_label)){
   stop("Explainer has the same label as label in fairness_object")
  }

  # cutoff handling- if cutoff is null than 0.5 for all subgroups
  group_levels <- levels(protected)
  n_lvl        <- length(group_levels)
  if (is.null(cutoff))                    cutoff <- rep(0.5, n_lvl)
  if (! is.numeric(cutoff))               stop("cutoff must be numeric scalar/ vector")
  if ( any(cutoff > 1) | any(cutoff < 0)) stop("cutoff must have values between 0 and 1")
  if (length(cutoff) == 1 & n_lvl != 1)    cutoff <- rep(cutoff, n_lvl)
  if (length(cutoff) != n_lvl)    stop("cutoff must be same length as number of subgroups (or lenght 1) ")



  ###############  fairness metric calculation  ###############

  verbose_cat("-> Metric calculation\t\t: ")

  created_na <- FALSE
  # number of metrics must be fixed. If changed add metric to metric labels
  # and change in calculate group fairness metrics
  metric_data   <- matrix(nrow = n_exp, ncol = 13)

  explainers_groups <- list(rep(0,n_exp))
  df                <- data.frame()
  cutoffs           <- as.list(rep(0, n_exp))
  names(cutoffs)    <- label

  for (i in seq_along(explainers)) {

    group_matrices <- group_matrices(protected = protected,
                                     probs = explainers[[i]]$y_hat,
                                     preds = explainers[[i]]$y,
                                     cutoff = cutoff)

    # storing cutoffs for explainers
    cutoffs[[label[i]]]        <- cutoff

    # group metric matrix
    gmm <- calculate_group_fairness_metrics(group_matrices)

    # from every column in matrix subtract base column, then get abs value
    # in other words we measure distance between base group
    # metrics score and other groups metric scores

    gmm_scaled      <- apply(gmm, 2 , function(x) x  - gmm[, privileged])
    gmm_abs         <- abs(gmm_scaled)
    gmm_loss        <- rowSums(gmm_abs)
    names(gmm_loss) <- paste0(names(gmm_loss),"_parity_loss")

    metric_data[i, ] <- gmm_loss


    # every group value for every metric for every explainer
    metric_list                 <- lapply(seq_len(nrow(gmm)), function(j) gmm[j,])
    names(metric_list)          <- rownames(gmm)
    explainers_groups[[i]]      <- metric_list
    names(explainers_groups)[i] <- label[i]

    ###############  fairness check  ###############

    fairness_check_data <- lapply(metric_list, function(y) y - y[privileged])

    # omit base metric because it is always 0
    fairness_check_data <- lapply(fairness_check_data,
                                  function(x) x[names(x) != privileged])

    statistical_parity_loss   <- fairness_check_data$STP
    equal_oportunity_loss     <- fairness_check_data$TPR
    predictive_parity_loss    <- fairness_check_data$PPV
    predictive_equality_loss  <- fairness_check_data$FPR
    accuracy_equality_loss    <- fairness_check_data$ACC

    n_sub <- length(unique(protected)) -1
    n_exp <- length(x$explainers)

    # creating data frames
    statistical_parity_data  <- data.frame(score    = unlist(statistical_parity_loss),
                                          subgroup = names(statistical_parity_loss),
                                          metric   = rep("Statistical parity loss   (TP + FP)/(TP + FP + TN + FN)", n_sub),
                                          model    = rep(label[i], n_sub))

    predictive_parity_data   <- data.frame(score    = unlist(predictive_parity_loss),
                                          subgroup = names(predictive_parity_loss),
                                          metric   = rep("Predictive parity loss    TP/(TP + FP)", n_sub),
                                          model    = rep(label[i], n_sub))

    equal_opportunity_data   <- data.frame(score    = unlist(equal_oportunity_loss),
                                          subgroup = names(equal_oportunity_loss),
                                          metric   = rep("Equal opportynity loss    TP/(TP + FN) ", n_sub),
                                          model    = rep(label[i], n_sub))

    predictive_equality_data <- data.frame(score    = unlist(predictive_equality_loss),
                                          subgroup = names(predictive_equality_loss),
                                          metric   = rep("Predictive equality loss   FP/(FP + TN)", n_sub),
                                          model    = rep(label[i], n_sub))

    accuracy_equality_data   <- data.frame(score    = unlist(accuracy_equality_loss),
                                          subgroup = names(accuracy_equality_loss),
                                          metric   = rep("Accuracy equality loss   (TP + FN)/(TP + FP + TN + FN) ", n_sub),
                                          model    = rep(label[i], n_sub))
    # add metrics to dataframe
    df <- rbind(df,
                equal_opportunity_data,
                predictive_parity_data,
                predictive_equality_data,
                accuracy_equality_data,
                statistical_parity_data)
  }

  if (any(is.na(metric_data))) created_na <- TRUE

  if (created_na){
    verbose_cat("successful (", color_codes$yellow_start, "NA created", color_codes$yellow_end, ")\n")
  } else {
    verbose_cat("successful\n")

  }

  ###############  Merging with fairness objects  ###############

  # as data frame and making numeric
  metric_data   <- as.data.frame(metric_data)


  metric_labels   <- paste0(c("TPR",
                              "TNR",
                              "PPV",
                              "NPV",
                              "FNR",
                              "FPR",
                              "FDR",
                              "FOR",
                              "TS",
                              "STP",
                              "ACC",
                              "F1",
                              "MCC"),
                              "_parity_loss")

  colnames(metric_data) <- metric_labels


  # merge explainers data with fobjects
  metric_data       <- rbind(metric_data, fobjects_metric_data)
  explainers_groups <- append(explainers_groups, fobjects_groups_data)
  df                <- rbind(df, fobjects_fcheck_data)
  cutoffs           <- append(cutoffs, fobjects_cuttofs)
  label             <- unlist(c(label, fobjects_label))
  names(cutoffs)           <- label
  names(explainers_groups) <- label


  # S3 object
  fairness_object <- list(metric_data = metric_data,
                          groups_data = explainers_groups,
                          explainers  = all_explainers,
                          privileged  = privileged,
                          protected   = protected,
                          label       = label,
                          cutoff      = cutoffs,
                          epsilon     = epsilon,
                          fairness_check_data = df)

  class(fairness_object) <- "fairness_object"

  verbose_cat(color_codes$green_start, "Fairness object created succesfully", color_codes$green_end, "\n")

  return(fairness_object)
}


color_codes <- list(yellow_start = "\033[33m", yellow_end = "\033[39m",
                    red_start = "\033[31m", red_end = "\033[39m",
                    green_start = "\033[32m", green_end = "\033[39m")


verbose_cat <- function(..., verbose = TRUE) {
  if (verbose) {
    cat(...)
  }
}







