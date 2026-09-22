# frozen_string_literal: true

RSpec.describe "image components" do
  let(:view) { build_view }

  it "renders a named zoom dialog and separate original" do
    doc = html(view.image_zoom("/small.jpg", alt: "Lake", zoom_src: "/large.jpg", class: "custom", id: "photo"))
    expect(doc.at("unmagic-image-zoom")['class']).to include("custom")
    expect(doc.at("unmagic-image-zoom")['id']).to eq("photo")
    expect(doc.at("button")['aria-haspopup']).to eq("dialog")
    expect(doc.at("dialog")['aria-label']).to eq("Lake")
    expect(doc.at("dialog img")['src']).to eq("/large.jpg")
    expect(doc.at("dialog")['open']).to be_nil
  end

  it "renders keyboard crop controls and an optional result field" do
    doc = html(view.image_crop("/lake.jpg", alt: "Lake", circular: true, name: "avatar", class: "custom"))
    expect(doc.at("unmagic-image-crop")['aspect']).to eq("1")
    expect(doc.at("unmagic-image-crop")['circular']).not_to be_nil
    expect(doc.css("label input[type=number]").size).to eq(4)
    expect(doc.at("input[type=hidden]")['name']).to eq("avatar")
    expect(doc.at("img")['crossorigin']).to eq("anonymous")
    expect(doc.at("[data-crop-preview]")["hidden"]).not_to be_nil
    expect(doc.at('[role=status]')).not_to be_nil
  end

  it "connects image sampling to an existing field" do
    doc = html(view.image_color_picker("/lake.jpg", alt: "Lake", input: "color", id: "picker", class: "custom"))
    expect(doc.at("unmagic-image-color-picker")['input']).to eq("color")
    expect(doc.at("unmagic-image-color-picker")['class']).to include("custom")
    expect(doc.at("button")['aria-label']).to include("arrow keys")
    expect(doc.at("output")['role']).to eq("status")
  end

  it "rejects missing sources and targets and invalid aspects" do
    expect { view.image_zoom("", alt: "") }.to raise_error(ArgumentError)
    expect { view.image_crop(nil, alt: "") }.to raise_error(ArgumentError)
    expect { view.image_color_picker("/a.jpg", alt: "", input: "") }.to raise_error(ArgumentError)
    [ 0, -1, Float::INFINITY, Float::NAN, "wide" ].each do |aspect|
      expect { view.image_crop("/a.jpg", alt: "", aspect: aspect) }.to raise_error(ArgumentError, /aspect/)
    end
  end
end
