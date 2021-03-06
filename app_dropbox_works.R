library(rdrop2)

outputDir <- "485_responses"

fieldsMandatory <- c("name", "favourite_pkg")

labelMandatory <- function(label) {
  tagList(label,
          span("*", class = "mandatory_star"))
}

appCSS <-
  ".mandatory_star { color: red; }
#error { color: red; }"

fieldsAll <-
  c("name",
    "favourite_pkg",
    "used_shiny",
    "r_num_years",
    "os_type")
responsesDir <- file.path("responses")
epochTime <- function() {
  as.integer(Sys.time())
}

loadData <- function() {
  files <- list.files(file.path(responsesDir), full.names = TRUE)
  data <- lapply(files, read.csv, stringsAsFactors = FALSE)
#  data <- dplyr::rbind_all(data)
  data <- dplyr::bind_rows(data)
  data
}

shinyApp(
  ui = fluidPage(
    shinyjs::useShinyjs(),
    shinyjs::inlineCSS(appCSS),
    titlePanel("Mimicking a Google Form with a Shiny app"),
    DT::dataTableOutput("responsesTable"),
    downloadButton("downloadBtn", "Download responses"),
    div(
      id = "form",
      
      textInput("name", labelMandatory("Name"), ""),
      textInput("favourite_pkg", labelMandatory("Favourite R package")),
      checkboxInput("used_shiny", "I've built a Shiny app in R before", FALSE),
      sliderInput("r_num_years", "Number of years using R", 0, 25, 2, ticks = FALSE),
      selectInput(
        "os_type",
        "Operating system used most frequently",
        c("",  "Windows", "Mac", "Linux")
      ),
      actionButton("submit", "Submit", class = "btn-primary"),
      shinyjs::hidden(span(id = "submit_msg", "Submitting..."),
                      div(id = "error",
                          div(
                            br(), tags$b("Error: "), span(id = "error_msg")
                          )))
    ),
    shinyjs::hidden(div(
      id = "thankyou_msg",
      h3("Thanks, your response was submitted successfully!"),
      actionLink("submit_another", "Submit another response")
    ))
  ),
  
  server = function(input, output, session) {
    observe({
      mandatoryFilled <-
        vapply(fieldsMandatory,
               function(x) {
                 !is.null(input[[x]]) && input[[x]] != ""
               },
               logical(1))
      mandatoryFilled <- all(mandatoryFilled)
      
      shinyjs::toggleState(id = "submit", condition = mandatoryFilled)
    })
    
    formData <- reactive({
      data <- sapply(fieldsAll, function(x)
        input[[x]])
      data <- c(data, timestamp = epochTime())
      data <- t(data)
      data
    })
    
    output$responsesTable <- DT::renderDataTable(
      loadData(),
      rownames = FALSE,
      options = list(searching = FALSE, lengthChange = FALSE)
    ) 
    
    output$downloadBtn <- downloadHandler(
      filename = function() { 
        sprintf("mimic-google-form_%s.csv", humanTime())
      },
      content = function(file) {
        write.csv(loadData(), file, row.names = FALSE)
      }
    )
    saveData <- function(data) {
      # data <- t(data)
      # Create a unique file name
      fileName <- sprintf("%s_%s.csv", as.integer(Sys.time()), digest::digest(data))
      # Write the data to a temporary file locally
      filePath <- file.path(tempdir(), fileName)
      write.csv(data, filePath, row.names = FALSE, quote = TRUE)
      # Upload the file to Dropbox
      drop_upload(filePath, path = outputDir)
    }
    
    loadData <- function() {
      # Read all the files into a list
      filesInfo <- drop_dir(outputDir)
      filePaths <- filesInfo$path_display
      data <- lapply(filePaths, drop_read_csv, stringsAsFactors = FALSE)
      # Concatenate all data together into one data.frame
      data <- do.call(rbind, data)
      data
    } 
    
    # action to take when submit button is pressed
    observeEvent(input$submit, {
      shinyjs::disable("submit")
      shinyjs::show("submit_msg")
      shinyjs::hide("error")
      
      tryCatch({
        saveData(formData())
        shinyjs::reset("form")
        shinyjs::hide("form")
        shinyjs::show("thankyou_msg")
      },
      error = function(err) {
        shinyjs::html("error_msg", err$message)
        shinyjs::show(id = "error", anim = TRUE, animType = "fade")
      },
      finally = {
        shinyjs::enable("submit")
        shinyjs::hide("submit_msg")
      })
    })
    
    observeEvent(input$submit_another, {
      shinyjs::show("form")
      shinyjs::hide("thankyou_msg")
    })
    humanTime <- function()
      format(Sys.time(), "%Y%m%d-%H%M%OS")
  }
)


#####
