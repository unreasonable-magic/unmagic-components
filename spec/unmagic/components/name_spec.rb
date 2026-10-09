# frozen_string_literal: true

RSpec.describe Unmagic::Components::Name do
  person = Unmagic::Components::Name::Person
  organization = Unmagic::Components::Name::Organization

  it "is a trimmed String" do
    name = described_class.new("  Ada  Lovelace ")

    expect(name).to be_a(String)
    expect(name).to eq("Ada  Lovelace")
    expect(described_class.new(nil)).to be_blank
    expect({ person.new("Jane Smith") => :ok }[person.new(" Jane Smith ")]).to eq(:ok)
  end

  it "reads the first and last words plainly" do
    expect(described_class.new("Ada Byron Lovelace").initials).to eq("AL")
    expect(described_class.new("Plato").initials).to eq("P")
    expect(described_class.new("Plato").last).to be_nil
    expect(described_class.new("Plato").initials_long).to eq("P")
  end

  describe Unmagic::Components::Name::Person do
    {
      "Jane Smith" => [ "Jane", "Smith", "JS", "Jane S." ],
      "Mary Jane Watson" => [ "Mary", "Watson", "MW", "Mary W." ],
      "Ludwig van Beethoven" => [ "Ludwig", "van Beethoven", "LB", "Ludwig V." ],
      "Jan van der Berg" => [ "Jan", "van der Berg", "JB", "Jan V." ],
      "Mary-Jane Watson-Smith" => [ "Mary-Jane", "Watson-Smith", "MW", "Mary-Jane W." ],
      "Prince" => [ "Prince", nil, "PR", "Prince" ],
      "x" => [ "x", nil, "X", "x" ],
      "  Jane   Smith  " => [ "Jane", "Smith", "JS", "Jane S." ],
      "👋 Jane Smith" => [ "Jane", "Smith", "JS", "Jane S." ],
      "👋" => [ "👋", nil, "", "👋" ]
    }.each do |input, (first, last, initials, short)|
      it "reads #{input.inspect}" do
        name = person.new(input)

        expect([ name.first, name.last, name.initials, name.short ]).to eq([ first, last, initials, short ])
        expect(name.initials_long).to eq(initials)
      end
    end
  end

  describe Unmagic::Components::Name::Organization do
    {
      "Kestrel Pty Ltd" => [ "KE", "KE" ],
      "Quiet Harbor Inc" => [ "QH", "QH" ],
      "Acme Corporation" => [ "AC", "AC" ],
      "Acme Widgets Pty. Ltd." => [ "AW", "AW" ],
      "BrightPath" => [ "BP", "BP" ],
      "TidePool" => [ "TP", "TP" ],
      "4K Gardens" => [ "4K", "4KG" ],
      "2Quill" => [ "2Q", "2Q" ],
      "Guild of Lanterns" => [ "GO", "GOL" ],
      "Limited" => [ "LI", "LI" ]
    }.each do |input, (initials, long)|
      it "reads #{input.inspect}" do
        expect([ organization.new(input).initials, organization.new(input).initials_long ]).to eq([ initials, long ])
      end
    end

    it "answers first and last with the name without its suffix, never emptying it" do
      expect(organization.new("Kestrel Pty Ltd").first).to eq("Kestrel")
      expect(organization.new("Quiet Harbor Inc").last).to eq("Quiet Harbor")
      expect(organization.new("Limited").first).to eq("Limited")
    end
  end
end
