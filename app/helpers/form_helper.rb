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

  def form_errors(record)
    return if record.errors.empty?

    tag.div(class: "banner banner--error", role: "alert") do
      icon("error") + tag.div do
        tag.strong("Corrija os campos abaixo:") + tag.ul { safe_join(record.errors.full_messages.map { |m| tag.li(m) }) }
      end
    end
  end
end
