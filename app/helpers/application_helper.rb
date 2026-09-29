module ApplicationHelper
  def icon(name, **options)
    tag.span(name, class: [ "msr", options.delete(:class) ].compact.join(" "), aria: { hidden: true }, **options)
  end

  def nav_item(label, icon_name, path, active:)
    link_to path, class: [ "nav-rail__item", ("is-active" if active) ].compact.join(" "), aria: { current: (active ? "page" : nil) } do
      tag.span(icon(icon_name), class: "nav-rail__indicator") + tag.span(label, class: "nav-rail__label")
    end
  end

  def status_chip(exchange_request)
    tag.span(exchange_request.status_label, class: "status-chip status-chip--#{exchange_request.status}")
  end

  def items_summary(exchange_request)
    items = exchange_request.exchange_request_items
    trocas = items.count(&:troca?)
    devolucoes = items.size - trocas
    [
      (pluralize(trocas, "troca", plural: "trocas") if trocas.positive?),
      (pluralize(devolucoes, "devolução", plural: "devoluções") if devolucoes.positive?)
    ].compact.join(" · ")
  end

  def brl(value)
    number_to_currency(value, unit: "R$ ", separator: ",", delimiter: ".")
  end

  def date_br(time)
    l(time, format: "%d/%m/%Y %H:%M") if time
  end
end
