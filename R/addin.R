# =============================================================================
# Phase 7: RStudio Addin
# =============================================================================

#' RStudio Addin: Join Inspector
#'
#' Opens an interactive dialog to explore join diagnostics between two
#' data frames in the current R environment.
#'
#' @return Called for side effects (opens Shiny gadget).
#'
#' @keywords internal
addin_join_inspector <- function() {
  if (!requireNamespace("shiny", quietly = TRUE)) {
    stop("The 'shiny' package is required for this addin. Install with: install.packages('shiny')", call. = FALSE)
  }
  if (!requireNamespace("miniUI", quietly = TRUE)) {
    stop("The 'miniUI' package is required for this addin. Install with: install.packages('miniUI')", call. = FALSE)
  }

  # Get data frames from global environment
  env <- globalenv()
  obj_names <- ls(envir = env)
  df_names <- obj_names[vapply(obj_names, function(n) {
    is.data.frame(get(n, envir = env))
  }, logical(1))]

  if (length(df_names) < 2) {
    stop("Need at least 2 data frames in the global environment", call. = FALSE)
  }

  ui <- miniUI::miniPage(
    miniUI::gadgetTitleBar("Join Inspector"),
    miniUI::miniContentPanel(
      shiny::fillCol(
        flex = c(NA, NA, NA, 1),
        shiny::fillRow(
          flex = c(1, 1),
          shiny::selectInput("left_df", "Left Table (x)",
                             choices = df_names,
                             selected = df_names[1]),
          shiny::selectInput("right_df", "Right Table (y)",
                             choices = df_names,
                             selected = if (length(df_names) > 1) df_names[2] else df_names[1])
        ),
        shiny::uiOutput("by_selector"),
        shiny::actionButton("run", "Run Diagnostics",
                            class = "btn-primary",
                            style = "margin: 10px 0;"),
        shiny::verbatimTextOutput("report")
      )
    )
  )

  server <- function(input, output, session) {
    # Dynamic column selector based on selected data frames
    output$by_selector <- shiny::renderUI({
      left <- input$left_df
      right <- input$right_df

      if (is.null(left) || is.null(right)) return(NULL)

      left_df <- get(left, envir = env)
      right_df <- get(right, envir = env)

      common_cols <- intersect(names(left_df), names(right_df))

      if (length(common_cols) == 0) {
        shiny::helpText("No common columns found between tables")
      } else {
        shiny::selectInput("by_cols", "Join Column(s)",
                           choices = common_cols,
                           selected = common_cols[1],
                           multiple = TRUE)
      }
    })

    # Run diagnostics
    report_text <- shiny::eventReactive(input$run, {
      left <- input$left_df
      right <- input$right_df
      by_cols <- input$by_cols

      if (is.null(left) || is.null(right) || is.null(by_cols)) {
        return("Please select tables and join columns")
      }

      left_df <- get(left, envir = env)
      right_df <- get(right, envir = env)

      # Capture print output
      report <- join_spy(left_df, right_df, by = by_cols)
      paste(utils::capture.output(print(report)), collapse = "\n")
    })

    output$report <- shiny::renderText({
      report_text()
    })

    # Handle done button
    shiny::observeEvent(input$done, {
      shiny::stopApp()
    })
  }

  viewer <- shiny::dialogViewer("Join Inspector", width = 700, height = 600)
  shiny::runGadget(ui, server, viewer = viewer)
}
