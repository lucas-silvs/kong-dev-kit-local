return {
  name = "my-plugin",
  fields = {
    { config = {
        type = "record",
        fields = {
          {
            example_field = { description = "An example for a field", type = "string" },
          },
        }, 
      }, 
    },
  },
}