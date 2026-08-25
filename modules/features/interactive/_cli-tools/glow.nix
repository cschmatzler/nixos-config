{
  theme,
  config,
}:
with theme.hex; {
  settings = {
    style = "${config.xdg.configHome}/glow/${theme.slug}.json";
    mouse = false;
    pager = false;
    width = 80;
    all = false;
  };

  theme = {
    document = {
      block_prefix = "\n";
      block_suffix = "\n";
      color = text;
      margin = 2;
    };
    block_quote = {
      color = subtle;
      italic = true;
      indent = 1;
      indent_token = "│ ";
    };
    list = {
      color = text;
      level_indent = 2;
    };
    heading = {
      block_suffix = "\n";
      color = iris;
      bold = true;
    };
    h1 = {
      prefix = "# ";
      bold = true;
    };
    h2.prefix = "## ";
    h3.prefix = "### ";
    h4.prefix = "#### ";
    h5.prefix = "##### ";
    h6.prefix = "###### ";
    strikethrough.crossed_out = true;
    emph = {
      italic = true;
      color = rose;
    };
    strong = {
      bold = true;
      color = pine;
    };
    hr = {
      color = highlightMed;
      format = "\n--------\n";
    };
    item.block_prefix = "• ";
    enumeration = {
      block_prefix = ". ";
      color = pine;
    };
    task = {
      ticked = "[✓] ";
      unticked = "[ ] ";
    };
    link = {
      color = pine;
      underline = true;
    };
    link_text.color = foam;
    image = {
      color = pine;
      underline = true;
    };
    image_text = {
      color = foam;
      format = "Image: {{.text}} →";
    };
    code = {
      color = gold;
      background_color = overlay;
      prefix = " ";
      suffix = " ";
    };
    code_block = {
      color = gold;
      margin = 2;
      chroma = {
        text.color = text;
        error = {
          color = base;
          background_color = love;
        };
        comment.color = muted;
        comment_preproc.color = foam;
        keyword.color = love;
        keyword_reserved.color = love;
        keyword_namespace.color = love;
        keyword_type.color = iris;
        operator.color = foam;
        punctuation.color = subtle;
        name.color = pine;
        name_constant.color = iris;
        name_builtin.color = rose;
        name_tag.color = love;
        name_attribute.color = rose;
        name_class.color = iris;
        name_decorator.color = foam;
        name_function.color = pine;
        literal_number.color = gold;
        literal_string.color = gold;
        literal_string_escape.color = rose;
        generic_deleted.color = love;
        generic_emph.italic = true;
        generic_inserted.color = pine;
        generic_strong.bold = true;
        generic_subheading.color = iris;
        background.background_color = overlay;
      };
    };
    table = {};
    definition_description.block_prefix = "\n🠶 ";
  };
}
