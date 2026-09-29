# Campos no estilo "outlined text field" do Material 3 (label flutuante).
module FormHelper
  def m3_field(form, attribute, label, as: :text_field, hint: nil, **options)
    errors = form.object&.errors&.[](attribute) || []
    textarea = as == :text_area
    classes = [ "text-field", ("text-field--textarea" if textarea), ("has-error" if errors.any?) ].compact.join(" ")

    tag.div(class: classes) do
      safe_join([
        form.public_send(as, attribute, placeholder: " ", **options),
        form.label(attribute, label),
        (tag.span(errors.any? ? errors.to_sentence.upcase_first : hint, class: "text-field__supporting") if errors.any? || hint)
      ].compact)
    end
  end

  def m3_switch(form, attribute, label, description = nil)
    tag.label(class: "switch-row") do
      safe_join([
        tag.span(class: "switch-row__text") do
          safe_join([ tag.span(label, class: "title-small"), (tag.span(description, class: "body-small muted") if description) ].compact)
        end,
        tag.span(class: "switch") do
          form.check_box(attribute, role: "switch") + tag.span(class: "switch__track") { tag.span(class: "switch__thumb") }
        end
      ])
    end
  end

  def m3_select(form, attribute, label, choices, hint: nil, **options)
    errors = form.object&.errors&.[](attribute) || []
    tag.div(class: [ "text-field text-field--select", ("has-error" if errors.any?) ].compact.join(" ")) do
      safe_join([
        form.select(attribute, choices, {}, options),
        form.label(attribute, label),
        (tag.span(errors.any? ? errors.to_sentence.upcase_first : hint, class: "text-field__supporting") if errors.any? || hint)
      ].compact)
    end
  end

  # Grupo de checkboxes para atributos array (ex.: return_modes, resolutions).
  def m3_checkbox_group(form, attribute, choices, locked: [])
    selected = Array(form.object.public_send(attribute))
    tag.div(class: "check-group") do
      safe_join([ form.hidden_field(attribute, multiple: true, value: "", id: nil) ] + choices.map do |value, text|
        forced = locked.include?(value)
        tag.label(class: [ "check-chip", ("is-locked" if forced) ].compact.join(" "), title: (forced ? "Obrigatório por lei" : nil)) do
          check_box_tag("#{form.object_name}[#{attribute}][]", value, selected.include?(value) || forced,
                        id: "#{form.object_name.to_s.parameterize(separator: "_")}_#{attribute}_#{value}") +
            tag.span { safe_join([ text, (icon("lock", class: "msr--sm") if forced) ].compact, " ") }
        end
      end)
    end
  end

  def form_errors(record)
    return if record.errors.empty?

    tag.div(class: "banner banner--error", role: "alert") do
      icon("error") + tag.div do
        tag.strong("Corrija os campos abaixo:") + tag.ul { safe_join(record.errors.full_messages.map { |m| tag.li(m) }) }
      end
    end
  end
end
