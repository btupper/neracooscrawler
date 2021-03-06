

#' A basic MURSST query function to retrieve one or more datasets
#'
#' @export
#' @param top character, uri of the top catalog
#' @param platform character, the name of the platform (MODISA)
#' @param product character, the product type (L3SMI)
#' @param year character or numeric, four digit year(s) - ignored if what is not 'all'
#' @param day character or numeric, three digit year of day(s) - ignored if what is not 'all'.
#'    You can improve efficiency by preselecting days for months, days, or seasons.
#' @param what character, optional filters
#'   \itemize{
#'       \item{all - return all occurences, the default, used with year and day, date_filter = NULL}
#'       \item{most_recent - return only the most recent, date_filter = NULL}
#'       \item{within - return the occurrences bounded by date_filter first and secomd elements}
#'       \item{before - return the occurences prior to the first date_filter element}
#'       \item{after - return the occurrences after the first date_filter element}
#'    }
#' @param date_filter POSIXct or Date, one or two element vector populated according to
#'    the \code{what} parameter.  By default NULL.  It is an error to not match 
#'    the value of date_filter  
#' @param verbose logical, by default FALSE
#' @return list of DatasetRefClass or NULL
#' @examples
#'    \dontrun{
#'       query <- MURSST_query(
#'          product = 'DailyFiles',
#'          what = 'most_recent')
#'       query <- MURSST_query( 
#'          what = 'within',
#'          date_filter = as.POSIXct(c("2008-01-01", "2008-06-01"), format = "%Y-%m-%d") )
#'    }
#' @seealso \code{\link{get_monthdays}}, \code{\link{get_8days}} and \code{\link{get_seasondays}}
MURSST_query <- function(
   top = "http://www.neracoos.org/thredds/catalog/GMRI/SATELLITE/NASA/MUR_SST/catalog.xml",
   region = 'NorthEastShelf', 
   product = 'DailyFiles',
   year = format(as.Date(Sys.Date()), "%Y"),
   day = format(as.Date(Sys.Date()), "%j"),
   what = c("all", "most_recent", "within", "before", "after")[1],
   date_filter = NULL,
   verbose = FALSE) {
      
   # Used to scan 'all' days for the listed year
   # Product CatalogRefClass
   # year one or more character in YYYY format
   # day one or more charcater in format JJJ
   get_all <- function(Product, year, day, verbose = FALSE) {
      #all for a given YEAR/DAY
      R <- NULL
      Years <- Product$get_catalogs()
      Y <- Years[year]
      Y <- Y[!sapply(Y, is.null)]
      if (!is.null(Y)){
         for (y in Y){
            Days <- y$GET()$get_catalogs()
            D <- Days[day]
            D <- D[!sapply(D, is.null)]
            if (!is.null(D)){
               for (d in D){
                  dtop <- d$GET()
                  if (!is.null(dtop)){
                     datasets <- dtop$get_datasets()
                     if (!is.null(datasets)){
                        R[names(datasets)] <- datasets
                     } # datasets?
                  } # dtop is !null
               } # D loop
            } # day is found
        } # Y loop 
      } #year is found   
      return(R)
   }   
   Top <- threddscrawler::get_catalog(top[1], verbose = verbose)
   if (is.null(Top)) {
      cat("error getting catalog for", top[1], "\n")
      return(NULL)
   }
   
   Platform <- Top$get_catalogs()[[platform[1]]]$GET()
   if (is.null(Platform)) {
      cat("error getting catalog for", platform[1], "\n")
      return(NULL)
   }
   
   Product <- Platform$get_catalogs()[[product[1]]]$GET()
   if (is.null(Product)) {
      cat("error getting catalog for", platform[1], "\n")
      return(NULL)
   }
   
   if (is.numeric(year)) year <- sprintf("%0.4i",year)
   if (is.numeric(day)) day <- sprintf("%0.3i", day)
   
   what <- tolower(what[1])
   R <- list()
   if (what == "most_recent"){
      while(length(R) == 0){
         Years <- Product$get_catalogs()
         for (y in rev(names(Years))){
            Y <- Years[[y]]$GET()
            Days <- Y$get_catalogs()
            for (d in rev(names(Days))){
               D <- Days[[d]]$GET()
               R <- D$get_datasets()
               if (length(R) != 0){ break }
            } #days 
            if (length(R) != 0){ break }
         } #years
      }
   
   } else if (what %in% c('within', "before", "after")){
   
      if (is.null(date_filter)){
         cat("if what is 'within', 'before' or 'after' then date_filter must be provided\n")
         return(NULL)
      }
      if ((what == 'within') && (length(date_filter) < 2) ) {
         cat("if what is 'within' then date_filter have [begin,end] elements\n")
         return(NULL)
      }   
      if (!inherits(date_filter, "POSIXt") && !inherits(date_filter, "Date")){
         cat("if what is 'within', 'before' or 'after' then date_filter must be POSIXt or Date class\n")
         return(NULL)
      }          
      
      # compute the beginning and end
      tbounds <-   switch(tolower(what),
            'within' = date_filter[1:2],
            'after' = c(date_filter[1], as.POSIXct(Sys.time())), # from then to present
            'before' = c( as.POSIXct("1990-01-01 00:00:00"), date_filter[1]) ) # from 1990 to then
      # convert to daily steps
      tsteps <- seq(tbounds[1], tbounds[2], by = 'day')
      year <- format(tsteps, "%Y")
      day <- format(tsteps,"%j")
      
      yd <- split(day, year)
      # note how this differs from what = 'all', here we explicitly iterate through
      # the years (days may be different for each year
      for (i in seq_along(yd)){
         y <- names(yd)[i]
         R[[y]] <- get_all(Product, y, yd[[i]], verbose = verbose)
      }

      R <- unlist(R, use.names = FALSE)
      names(R) <- sapply(R, function(x) x$name)
   
   } else {
      # retrieve the days from the years specified
      R <- get_all(Product, year, day)
   }
   
   # if none found then we return NULL (not an empty list)
   if (length(R) == 0) R <- NULL
   if (verbose){
      cat(sprintf("MURSST_query: retrieved %i records\n", length(R)))
   }
   invisible(R)   
}


