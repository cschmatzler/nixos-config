{
	config,
	theme,
}: let
	palette = theme.hex;
in {
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
			color = palette.text;
			margin = 2;
		};
		block_quote = {
			color = palette.subtle;
			italic = true;
			indent = 1;
			indent_token = "│ ";
		};
		list = {
			color = palette.text;
			level_indent = 2;
		};
		heading = {
			block_suffix = "\n";
			color = palette.iris;
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
			color = palette.rose;
		};
		strong = {
			bold = true;
			color = palette.pine;
		};
		hr = {
			color = palette.highlightMed;
			format = "\n--------\n";
		};
		item.block_prefix = "• ";
		enumeration = {
			block_prefix = ". ";
			color = palette.pine;
		};
		task = {
			ticked = "[✓] ";
			unticked = "[ ] ";
		};
		link = {
			color = palette.pine;
			underline = true;
		};
		link_text.color = palette.foam;
		image = {
			color = palette.pine;
			underline = true;
		};
		image_text = {
			color = palette.foam;
			format = "Image: {{.text}} →";
		};
		code = {
			color = palette.gold;
			background_color = palette.overlay;
			prefix = " ";
			suffix = " ";
		};
		code_block = {
			color = palette.gold;
			margin = 2;
			chroma = {
				text.color = palette.text;
				error = {
					color = palette.base;
					background_color = palette.love;
				};
				comment.color = palette.muted;
				comment_preproc.color = palette.foam;
				keyword.color = palette.love;
				keyword_reserved.color = palette.love;
				keyword_namespace.color = palette.love;
				keyword_type.color = palette.iris;
				operator.color = palette.foam;
				punctuation.color = palette.subtle;
				name.color = palette.pine;
				name_constant.color = palette.iris;
				name_builtin.color = palette.rose;
				name_tag.color = palette.love;
				name_attribute.color = palette.rose;
				name_class.color = palette.iris;
				name_decorator.color = palette.foam;
				name_function.color = palette.pine;
				literal_number.color = palette.gold;
				literal_string.color = palette.gold;
				literal_string_escape.color = palette.rose;
				generic_deleted.color = palette.love;
				generic_emph.italic = true;
				generic_inserted.color = palette.pine;
				generic_strong.bold = true;
				generic_subheading.color = palette.iris;
				background.background_color = palette.overlay;
			};
		};
		table = {};
		definition_description.block_prefix = "\n🠶 ";
	};
}
