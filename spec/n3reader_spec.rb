# coding: utf-8
$:.unshift "."
require File.join(File.dirname(__FILE__), 'spec_helper')

describe "RDF::N3::Reader" do
    context "discovery" do
      {
        "n3" => RDF::Reader.for(:n3),
        "etc/foaf.n3" => RDF::Reader.for("etc/foaf.n3"),
        "etc/foaf.ttl" => RDF::Reader.for("etc/foaf.ttl"),
        "foaf.n3" => RDF::Reader.for(:file_name      => "foaf.n3"),
        "foaf.ttl" => RDF::Reader.for(:file_name      => "foaf.ttl"),
        ".n3" => RDF::Reader.for(:file_extension => "n3"),
        ".ttl" => RDF::Reader.for(:file_extension => "ttl"),
        "text/n3" => RDF::Reader.for(:content_type   => "text/n3"),
        "text/turtle" => RDF::Reader.for(:content_type   => "text/turtle"),
      }.each_pair do |label, format|
        it "should discover '#{label}'" do
          format.should == RDF::N3::Reader
        end
      end
    end

    context :interface do
      before(:each) do
        @sampledoc = <<-EOF;
          @prefix dc: <http://purl.org/dc/elements/1.1/>.
          @prefix po: <http://purl.org/ontology/po/>.
          @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>.
          _:broadcast
           a po:Broadcast;
           po:schedule_date """2008-06-24T12:00:00Z""";
           po:broadcast_of _:version;
           po:broadcast_on <http://www.bbc.co.uk/programmes/service/6music>;
          .
          _:version
           a po:Version;
          .
          <http://www.bbc.co.uk/programmes/b0072l93>
           dc:title """Nemone""";
           a po:Brand;
          .
          <http://www.bbc.co.uk/programmes/b00c735d>
           a po:Episode;
           po:episode <http://www.bbc.co.uk/programmes/b0072l93>;
           po:version _:version;
           po:long_synopsis """Actor and comedian Rhys Darby chats to Nemone.""";
           dc:title """Nemone""";
           po:synopsis """Actor and comedian Rhys Darby chats to Nemone.""";
          .
          <http://www.bbc.co.uk/programmes/service/6music>
           a po:Service;
           dc:title """BBC 6 Music""";
          .

          #_:abcd a po:Episode.
      EOF
    end
    
    it "should yield reader" do
      inner = mock("inner")
      inner.should_receive(:called).with(RDF::N3::Reader)
      RDF::N3::Reader.new(@sampledoc) do |reader|
        inner.called(reader.class)
      end
    end
    
    it "should return reader" do
      RDF::N3::Reader.new(@sampledoc).should be_a(RDF::N3::Reader)
    end
    
    it "should yield statements" do
      inner = mock("inner")
      inner.should_receive(:called).with(RDF::Statement).exactly(15)
      RDF::N3::Reader.new(@sampledoc).each_statement do |statement|
        inner.called(statement.class)
      end
    end
    
    it "should yield triples" do
      inner = mock("inner")
      inner.should_receive(:called).exactly(15)
      RDF::N3::Reader.new(@sampledoc).each_triple do |subject, predicate, object|
        inner.called(subject.class, predicate.class, object.class)
      end
    end
  end

  describe "with simple ntriples" do
    context "simple triple" do
      before(:each) do
        n3_string = %(<http://example.org/> <http://xmlns.com/foaf/0.1/name> "Gregg Kellogg" .)
        @graph = parse(n3_string)
        @statement = @graph.statements.first
      end
      
      it "should have a single triple" do
        @graph.size.should == 1
      end
      
      it "should have subject" do
        @statement.subject.to_s.should == "http://example.org/"
      end
      it "should have predicate" do
        @statement.predicate.to_s.should == "http://xmlns.com/foaf/0.1/name"
      end
      it "should have object" do
        @statement.object.to_s.should == "Gregg Kellogg"
      end
    end
    
    # NTriple tests from http://www.w3.org/2000/10/rdf-tests/rdfcore/ntriples/test.nt
    describe "with blank lines" do
      {
        "comment"                   => "# comment lines",
        "comment after whitespace"  => "            # comment after whitespace",
        "empty line"                => "",
        "line with spaces"          => "      "
      }.each_pair do |name, statement|
        specify "test #{name}" do
          parse(statement).size.should == 0
        end
      end
    end

    describe "with literal encodings" do
      {
        'Dürst' => ':a :b "D\u00FCrst" .',
        'simple literal' => ':a :b  "simple literal" .',
        'backslash:\\' => ':a :b  "backslash:\\\\" .',
        'dquote:"' => ':a :b  "dquote:\"" .',
        "newline:\n" => ':a :b  "newline:\n" .',
        "return\r" => ':a :b  "return\r" .',
        "tab:\t" => ':a :b  "tab:\t" .',
        "é" => ':a :b  "\u00E9" .',
        "€" => ':a :b  "\u20AC" .',
      }.each_pair do |contents, triple|
        specify "test #{contents}" do
          graph = parse(triple, :base_uri => "http://a/b")
          statement = graph.statements.first
          graph.size.should == 1
          statement.object.value.should == contents
        end
      end
      
      it "should parse long literal with escape" do
        n3 = %(@prefix : <http://example.org/foo#> . :a :b "\\U00015678another" .)
        if defined?(::Encoding)
          statement = parse(n3).statements.first
          statement.object.value.should == "\u{15678}another"
        else
          pending("Not supported in Ruby 1.8")
        end
      end

      it "should parse multi-line literal" do
        graph = parse(%(
  <http://www.example.com/books#book12345> <http://purl.org/dc/terms/title> """
          Foo
          <html:b xmlns:html="http://www.w3.org/1999/xhtml" html:a="b">bar<rdf:Thing xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"><a:b xmlns:a="foo:"></a:b>here<a:c xmlns:a="foo:"></a:c></rd
  f:Thing></html:b>
          baz
          <html:i xmlns:html="http://www.w3.org/1999/xhtml">more</html:i>
       """ .
        ))

        graph.size.should == 1
        graph.statements.first.object.value.should == %(
          Foo
          <html:b xmlns:html="http://www.w3.org/1999/xhtml" html:a="b">bar<rdf:Thing xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"><a:b xmlns:a="foo:"></a:b>here<a:c xmlns:a="foo:"></a:c></rd
  f:Thing></html:b>
          baz
          <html:i xmlns:html="http://www.w3.org/1999/xhtml">more</html:i>
       )
      end
      
      it "should parse long literal ending in double quote" do
        graph = parse(%(:a :b """ \\"""" .), :base_uri => "http://a/b")
        graph.size.should == 1
        graph.statements.first.object.value.should == ' "'
      end
    end

    it "should create named subject bnode" do
      graph = parse("_:anon <http://example.org/property> <http://example.org/resource2> .")
      graph.size.should == 1
      statement = graph.statements.first
      statement.subject.should be_a(RDF::Node)
      statement.subject.id.should =~ /anon/
      statement.predicate.to_s.should == "http://example.org/property"
      statement.object.to_s.should == "http://example.org/resource2"
    end

    it "should create named predicate bnode" do
      graph = parse("<http://example.org/resource2> _:anon <http://example.org/object> .")
      graph.size.should == 1
      statement = graph.statements.first
      statement.subject.to_s.should == "http://example.org/resource2"
      statement.predicate.should be_a(RDF::Node)
      statement.predicate.id.should =~ /anon/
      statement.object.to_s.should == "http://example.org/object"
    end

    it "should create named object bnode" do
      graph = parse("<http://example.org/resource2> <http://example.org/property> _:anon .")
      graph.size.should == 1
      statement = graph.statements.first
      statement.subject.to_s.should == "http://example.org/resource2"
      statement.predicate.to_s.should == "http://example.org/property"
      statement.object.should be_a(RDF::Node)
      statement.object.id.should =~ /anon/
    end

    {
      "three uris"  => "<http://example.org/resource1> <http://example.org/property> <http://example.org/resource2> .",
      "spaces and tabs throughout" => " 	 <http://example.org/resource3> 	 <http://example.org/property>	 <http://example.org/resource2> 	.	 ",
      "line ending with CR NL" => "<http://example.org/resource4> <http://example.org/property> <http://example.org/resource2> .\r\n",
      "literal escapes (1)" => '<http://example.org/resource7> <http://example.org/property> "simple literal" .',
      "literal escapes (2)" => '<http://example.org/resource8> <http://example.org/property> "backslash:\\\\" .',
      "literal escapes (3)" => '<http://example.org/resource9> <http://example.org/property> "dquote:\"" .',
      "literal escapes (4)" => '<http://example.org/resource10> <http://example.org/property> "newline:\n" .',
      "literal escapes (5)" => '<http://example.org/resource11> <http://example.org/property> "return:\r" .',
      "literal escapes (6)" => '<http://example.org/resource12> <http://example.org/property> "tab:\t" .',
      "Space is optional before final . (1)" => ['<http://example.org/resource13> <http://example.org/property> <http://example.org/resource2>.', '<http://example.org/resource13> <http://example.org/property> <http://example.org/resource2> .'],
      "Space is optional before final . (2)" => ['<http://example.org/resource14> <http://example.org/property> "x".', '<http://example.org/resource14> <http://example.org/property> "x" .'],

      "XML Literals as Datatyped Literals (1)" => '<http://example.org/resource21> <http://example.org/property> ""^^<http://www.w3.org/2000/01/rdf-schema#XMLLiteral> .',
      "XML Literals as Datatyped Literals (2)" => '<http://example.org/resource22> <http://example.org/property> " "^^<http://www.w3.org/2000/01/rdf-schema#XMLLiteral> .',
      "XML Literals as Datatyped Literals (3)" => '<http://example.org/resource23> <http://example.org/property> "x"^^<http://www.w3.org/2000/01/rdf-schema#XMLLiteral> .',
      "XML Literals as Datatyped Literals (4)" => '<http://example.org/resource23> <http://example.org/property> "\""^^<http://www.w3.org/2000/01/rdf-schema#XMLLiteral> .',
      "XML Literals as Datatyped Literals (5)" => '<http://example.org/resource24> <http://example.org/property> "<a></a>"^^<http://www.w3.org/2000/01/rdf-schema#XMLLiteral> .',
      "XML Literals as Datatyped Literals (6)" => '<http://example.org/resource25> <http://example.org/property> "a <b></b>"^^<http://www.w3.org/2000/01/rdf-schema#XMLLiteral> .',
      "XML Literals as Datatyped Literals (7)" => '<http://example.org/resource26> <http://example.org/property> "a <b></b> c"^^<http://www.w3.org/2000/01/rdf-schema#XMLLiteral> .',
      "XML Literals as Datatyped Literals (8)" => '<http://example.org/resource26> <http://example.org/property> "a\n<b></b>\nc"^^<http://www.w3.org/2000/01/rdf-schema#XMLLiteral> .',
      "XML Literals as Datatyped Literals (9)" => '<http://example.org/resource27> <http://example.org/property> "chat"^^<http://www.w3.org/2000/01/rdf-schema#XMLLiteral> .',
      
      "Plain literals with languages (1)" => '<http://example.org/resource30> <http://example.org/property> "chat"@fr .',
      "Plain literals with languages (2)" => '<http://example.org/resource31> <http://example.org/property> "chat"@en .',
      
      "Typed Literals" => '<http://example.org/resource32> <http://example.org/property> "abc"^^<http://example.org/datatype1> .',
    }.each_pair do |name, statement|
      specify "test #{name}" do
        graph = parse([statement].flatten.first)
        graph.size.should == 1
        graph.to_ntriples.chomp.should == [statement].flatten.last.gsub(/\s+/, " ").strip
      end
    end

    it "should create typed literals" do
      n3doc = "<http://example.org/joe> <http://xmlns.com/foaf/0.1/name> \"Joe\"^^<http://www.w3.org/2001/XMLSchema#string> ."
      statement = parse(n3doc).statements.first
      statement.object.class.should == RDF::Literal
    end

    it "should create BNodes" do
      n3doc = "_:a a _:c ."
      statement = parse(n3doc).statements.first
      statement.subject.class.should == RDF::Node
      statement.object.class.should == RDF::Node
    end

    describe "should create URIs" do
      {
        %(<http://example.org/joe> <http://xmlns.com/foaf/0.1/knows> <http://example.org/jane> .) => %(<http://example.org/joe> <http://xmlns.com/foaf/0.1/knows> <http://example.org/jane> .),
        %(<joe> <knows> <jane> .) => %(<http://a/joe> <http://a/knows> <http://a/jane> .),
        %(:joe :knows :jane .) => %(<http://a/b#joe> <http://a/b#knows> <http://a/b#jane> .),
        %(<#D%C3%BCrst>  a  "URI percent ^encoded as C3, BC".) => %(<http://a/b#D%C3%BCrst> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> "URI percent ^encoded as C3, BC" .),
      }.each_pair do |n3, nt|
        it "for '#{n3}'" do
          parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
        end
      end

      {
        %(<#Dürst>       a  "URI straight in UTF8".) => %(<http://a/b#D\\u00FCrst> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> "URI straight in UTF8" .),
        #%(:a :related :ひらがな .) => %(<http://a/b#a> <http://a/b#related> <http://a/b#\\u3072\\u3089\\u304C\\u306A> .),
      }.each_pair do |n3, nt|
        it "for '#{n3}'" do
          begin
            parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
          rescue
            if defined?(::Encoding)
              raise
            else
              pending("Unicode URIs not supported in Ruby 1.8") {  raise } 
            end
          end
        end
      end
    end
    
    it "should create URIs" do
      n3doc = "<http://example.org/joe> <http://xmlns.com/foaf/0.1/knows> <http://example.org/jane> ."
      statement = parse(n3doc).statements.first
      statement.subject.class.should == RDF::URI
      statement.object.class.should == RDF::URI
    end

    it "should create literals" do
      n3doc = "<http://example.org/joe> <http://xmlns.com/foaf/0.1/name> \"Joe\"."
      statement = parse(n3doc).statements.first
      statement.object.class.should == RDF::Literal
    end
  end
  
  # describe "with illegal syntax" do
  #   {
  #     %(:y :p1 "xyz"^^xsd:integer .) => %r(Typed literal has an invalid lexical value: .* "xyz"),
  #     %(:y :p1 "12xyz"^^xsd:integer .) => %r(Typed literal has an invalid lexical value: .* "12xyz"),
  #     %(:y :p1 "xy.z"^^xsd:double .) => %r(Typed literal has an invalid lexical value: .* "xy\.z"),
  #     %(:y :p1 "+1.0z"^^xsd:double .) => %r(Typed literal has an invalid lexical value: .* "\+1.0z"),
  #     %(:a :b .) => %r(Illegal statment: ".*" missing object),
  #     %(:a :b 'single quote' .) => RDF::ReaderError,
  #     %(:a "literal value" :b .) => RDF::ReaderError,
  #     %(@keywords prefix. :e prefix :f .) => %r(Keyword ".*" used as expression)
  #   }.each_pair do |n3, error|
  #     it "should raise error for '#{n3}'" do
  #       lambda {
  #         parse("@prefix xsd: <http://www.w3.org/2001/XMLSchema#> . #{n3}", :base_uri => "http://a/b")
  #       }.should raise_error(error)
  #     end
  #   end
  # end
  
  describe "with n3 grammer" do
    describe "syntactic expressions" do
      it "should create typed literals with qname" do
        n3doc = %(
          @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
          @prefix foaf: <http://xmlns.com/foaf/0.1/>
          @prefix xsd: <http://www.w3.org/2001/XMLSchema#>
          <http://example.org/joe> foaf:name \"Joe\"^^xsd:string .
        )
        statement = parse(n3doc).statements.first
        statement.object.class.should == RDF::Literal
      end

      it "should use <> as a prefix and as a triple node" do
        n3 = %(@prefix : <> . <> a :a.)
        nt = %(
        <http://a/b> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://a/ba> .
        )
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end
      
      it "should use <#> as a prefix and as a triple node" do
        n3 = %(@prefix : <#> . <#> a :a.)
        nt = %(
        <http://a/b#> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://a/b#a> .
        )
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end
      
      it "should generate rdf:type for 'a'" do
        n3 = %(@prefix a: <http://foo/a#> . a:b a <http://www.w3.org/2000/01/rdf-schema#resource> .)
        nt = %(<http://foo/a#b> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2000/01/rdf-schema#resource> .)
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end
      
      it "should generate rdf:type for '@a'" do
        n3 = %(@prefix a: <http://foo/a#> . a:b @a <http://www.w3.org/2000/01/rdf-schema#resource> .)
        nt = %(<http://foo/a#b> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2000/01/rdf-schema#resource> .)
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end
      
      it "should generate inverse predicate for 'is xxx of'" do
        n3 = %("value" is :prop of :b . :b :prop "value"  .)
        nt = %(<http://a/b#b> <http://a/b#prop> "value" .)
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end
      
      it "should generate inverse predicate for '@is xxx @of'" do
        n3 = %("value" @is :prop @of :b . :b :prop "value" .)
        nt = %(<http://a/b#b> <http://a/b#prop> "value" .)
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end
      
      it "should generate inverse predicate for 'is xxx of' with object list" do
        n3 = %("value" is :prop of :b, :c . )
        nt = %(
        <http://a/b#b> <http://a/b#prop> "value" .
        <http://a/b#c> <http://a/b#prop> "value" .
        )
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end
      
      it "should generate predicate for 'has xxx'" do
        n3 = %(@prefix a: <http://foo/a#> . a:b has :pred a:c .)
        nt = %(<http://foo/a#b> <http://a/b#pred> <http://foo/a#c> .)
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end
      
      it "should generate predicate for '@has xxx'" do
        n3 = %(@prefix a: <http://foo/a#> . a:b @has :pred a:c .)
        nt = %(<http://foo/a#b> <http://a/b#pred> <http://foo/a#c> .)
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end
      
      it "should create log:implies predicate for '=>'" do
        n3 = %(@prefix a: <http://foo/a#> . _:a => a:something .)
        nt = %(_:a <http://www.w3.org/2000/10/swap/log#implies> <http://foo/a#something> .)
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end
      
      it "should create log:implies inverse predicate for '<='" do
        n3 = %(@prefix a: <http://foo/a#> . _:a <= a:something .)
        nt = %(<http://foo/a#something> <http://www.w3.org/2000/10/swap/log#implies> _:a .)
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end
      
      it "should create owl:sameAs predicate for '='" do
        n3 = %(@prefix a: <http://foo/a#> . _:a = a:something .)
        nt = %(_:a <http://www.w3.org/2002/07/owl#sameAs> <http://foo/a#something> .)
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end
      
      {
        %(:a :b @true)  => %(<http://a/b#a> <http://a/b#b> "true"^^<http://www.w3.org/2001/XMLSchema#boolean> .),
        %(:a :b @false)  => %(<http://a/b#a> <http://a/b#b> "false"^^<http://www.w3.org/2001/XMLSchema#boolean> .),
        %(:a :b 1)  => %(<http://a/b#a> <http://a/b#b> "1"^^<http://www.w3.org/2001/XMLSchema#integer> .),
        %(:a :b -1)  => %(<http://a/b#a> <http://a/b#b> "-1"^^<http://www.w3.org/2001/XMLSchema#integer> .),
        %(:a :b +1)  => %(<http://a/b#a> <http://a/b#b> "+1"^^<http://www.w3.org/2001/XMLSchema#integer> .),
        %(:a :b 1.0)  => %(<http://a/b#a> <http://a/b#b> "1.0"^^<http://www.w3.org/2001/XMLSchema#decimal> .),
        %(:a :b 1.0e1)  => %(<http://a/b#a> <http://a/b#b> "1.0e1"^^<http://www.w3.org/2001/XMLSchema#double> .),
        %(:a :b 1.0e-1)  => %(<http://a/b#a> <http://a/b#b> "1.0e-1"^^<http://www.w3.org/2001/XMLSchema#double> .),
        %(:a :b 1.0e+1)  => %(<http://a/b#a> <http://a/b#b> "1.0e+1"^^<http://www.w3.org/2001/XMLSchema#double> .),
      }.each_pair do |n3, nt|
        it "should create typed literal for '#{n3}'" do
          parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
        end
      end
      
      it "should accept empty localname" do
        n3 = %(: : : .)
        nt = %(<http://a/b#> <http://a/b#> <http://a/b#> .)
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end
      
      it "should accept prefix with empty local name" do
        n3 = %(@prefix foo: <http://foo/bar#> . foo: foo: foo: .)
        nt = %(<http://foo/bar#> <http://foo/bar#> <http://foo/bar#> .)
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end
      
      it "should do something for @forAll"

      it "should do something for @forSome"
    end
    
    describe "namespaces" do
      it "should not append # for http://foo/bar" do
        n3 = %(@prefix : <http://foo/bar> . :a : :b .)
        nt = %(
        <http://foo/bara> <http://foo/bar> <http://foo/barb> .
        )
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end

      it "should not append # for http://foo/bar/" do
        n3 = %(@prefix : <http://foo/bar/> . :a : :b .)
        nt = %(
        <http://foo/bar/a> <http://foo/bar/> <http://foo/bar/b> .
        )
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end

      it "should not append # for http://foo/bar#" do
        n3 = %(@prefix : <http://foo/bar#> . :a : :b .)
        nt = %(
        <http://foo/bar#a> <http://foo/bar#> <http://foo/bar#b> .
        )
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end

      it "should set absolute base" do
        n3 = %(@base <http://foo/bar> . <> :a <b> . <#c> :d </e>.)
        nt = %(
        <http://foo/bar> <http://foo/bar#a> <http://foo/b> .
        <http://foo/bar#c> <http://foo/bar#d> <http://foo/e> .
        )
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end
      
      it "should set absolute base (trailing /)" do
        n3 = %(@base <http://foo/bar/> . <> :a <b> . <#c> :d </e>.)
        nt = %(
        <http://foo/bar/> <http://foo/bar/a> <http://foo/bar/b> .
        <http://foo/bar/#c> <http://foo/bar/d> <http://foo/e> .
        )
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end
      
      it "should set absolute base (trailing #)" do
        n3 = %(@base <http://foo/bar#> . <> :a <b> . <#c> :d </e>.)
        nt = %(
        <http://foo/bar#> <http://foo/bar#a> <http://foo/b> .
        <http://foo/bar#c> <http://foo/bar#d> <http://foo/e> .
        )
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end
      
      it "should set relative base" do
        n3 = %(
        @base <http://example.org/products/>.
        <> :a <b>, <#c>.
        @base <prod123/>.
        <> :a <b>, <#c>.
        @base <../>.
        <> :a <d>, <#e>.
        )
        nt = %(
        <http://example.org/products/> <http://example.org/products/a> <http://example.org/products/b> .
        <http://example.org/products/> <http://example.org/products/a> <http://example.org/products/#c> .
        <http://example.org/products/prod123/> <http://example.org/products/prod123/a> <http://example.org/products/prod123/b> .
        <http://example.org/products/prod123/> <http://example.org/products/prod123/a> <http://example.org/products/prod123/#c> .
        <http://example.org/products/> <http://example.org/products/a> <http://example.org/products/d> .
        <http://example.org/products/> <http://example.org/products/a> <http://example.org/products/#e> .
        )
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end
    end
    
    describe "keywords" do
      [
        %(prefix :<>.),
        %(base <>.),
        %(keywords a.),
        %(:a is :b of :c.),
        %(:a @is :b of :c.),
        %(:a is :b @of :c.),
        %(:a has :b :c.),
      ].each do |n3|
        it "should require @ if keywords set to empty for '#{n3}'" do
          lambda do
            parse("@keywords . #{n3}", :base_uri => "http://a/b")
          end.should raise_error(/unqualified keyword '\w+' used without @keyword directive/)
        end
      end
      
      {
        %(:a a :b)  => %(<http://a/b#a> <http://a/b#a> <http://a/b#b> .),
        %(:a :b true) => %(<http://a/b#a> <http://a/b#b> <http://a/b#true> .),
        %(:a :b false) => %(<http://a/b#a> <http://a/b#b> <http://a/b#false> .),
        %(c :a :t)  => %(<http://a/b#c> <http://a/b#a> <http://a/b#t> .),
        %(:c a :t)  => %(<http://a/b#c> <http://a/b#a> <http://a/b#t> .),
        %(:c :a t)  => %(<http://a/b#c> <http://a/b#a> <http://a/b#t> .),
      }.each_pair do |n3, nt|
        it "should use default_ns for '#{n3}'" do
          parse("@keywords . #{n3}", :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
        end
      end

      {
        %(@keywords true. :a :b true.) => %(<http://a/b#a> <http://a/b#b> "true"^^<http://www.w3.org/2001/XMLSchema#boolean> .),
        %(@keywords false. :a :b false.) => %(<http://a/b#a> <http://a/b#b> "false"^^<http://www.w3.org/2001/XMLSchema#boolean> .),
        %(@keywords a. :a a :b.) => %(<http://a/b#a> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://a/b#b> .),
        %(@keywords is. :a is :b @of :c.) => %(<http://a/b#c> <http://a/b#b> <http://a/b#a> .),
        %(@keywords of. :a @is :b of :c.) => %(<http://a/b#c> <http://a/b#b> <http://a/b#a> .),
        %(@keywords has. :a has :b :c.) => %(<http://a/b#a> <http://a/b#b> <http://a/b#c> .),
      }  .each_pair do |n3, nt|
          it "should use keyword for '#{n3}'" do
            parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
          end
        end
      
      it "should raise error if unknown keyword set" do
        n3 = %(@keywords foo.)
        lambda do
          parse(n3, :base_uri => "http://a/b")
        end.should raise_error(RDF::ReaderError, "undefined keywords used: foo")
      end
    end
    
    describe "declaration ordering" do
      it "should process _ namespace binding after an initial use as a BNode" do
        n3 = %(
        _:a a :p.
        @prefix _: <http://underscore/> .
        _:a a :p.
        )
        nt = %(
        <http://underscore/a> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://a/b#p> .
        _:a <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://a/b#p> .
        )
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end
      
      it "should allow a prefix to be redefined" do
        n3 = %(
        @prefix a: <http://host/A#>.
        a:b a:p a:v .

        @prefix a: <http://host/Z#>.
        a:b a:p a:v .
        )
        nt = %(
        <http://host/A#b> <http://host/A#p> <http://host/A#v> .
        <http://host/Z#b> <http://host/Z#p> <http://host/Z#v> .
        )
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end

      it "should process sequential @base declarations (swap base.n3)" do
        n3 = %(
        @base <http://example.com/ontolgies>. <a> :b <foo/bar#baz>.
        @base <path/DFFERENT/>. <a2> :b2 <foo/bar#baz2>.
        @prefix : <#>. <d3> :b3 <e3>.
        )
        nt = %(
        <http://example.com/a> <http://example.com/ontolgies#b> <http://example.com/foo/bar#baz> .
        <http://example.com/path/DFFERENT/a2> <http://example.com/path/DFFERENT/b2> <http://example.com/path/DFFERENT/foo/bar#baz2> .
        <http://example.com/path/DFFERENT/d3> <http://example.com/path/DFFERENT/#b3> <http://example.com/path/DFFERENT/e3> .
        )
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end
    end
    
    describe "BNodes" do
      it "should create BNode for identifier with '_' prefix" do
        n3 = %(@prefix a: <http://foo/a#> . _:a a:p a:v .)
        nt = %(_:bnode0 <http://foo/a#p> <http://foo/a#v> .)
      end
      
      it "should create BNode for [] as subject" do
        n3 = %(@prefix a: <http://foo/a#> . [] a:p a:v .)
        nt = %(_:bnode0 <http://foo/a#p> <http://foo/a#v> .)
        g = parse(n3, :base_uri => "http://a/b")
        normalize_bnodes(g, "bnode0").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug, :compare => :array)
      end
      
      it "should create BNode for [] as predicate" do
        n3 = %(@prefix a: <http://foo/a#> . a:s [] a:o .)
        nt = %(<http://foo/a#s> _:bnode0 <http://foo/a#o> .)
        g = parse(n3, :base_uri => "http://a/b")
        normalize_bnodes(g, "bnode0").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug, :compare => :array, :anon => "bnode")
      end
      
      it "should create BNode for [] as object" do
        n3 = %(@prefix a: <http://foo/a#> . a:s a:p [] .)
        nt = %(<http://foo/a#s> <http://foo/a#p> _:bnode0 .)
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end
      
      it "should create BNode for [] as statement" do
        n3 = %([:a :b] .)
        nt = %(_:bnode0 <http://a/b#a> <http://a/b#b> .)
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end
      
      it "should create statements with BNode subjects using [ pref obj]" do
        n3 = %(@prefix a: <http://foo/a#> . [ a:p a:v ] .)
        nt = %(_:bnode0 <http://foo/a#p> <http://foo/a#v> .)
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end
      
      it "should create BNode as a single object" do
        n3 = %(@prefix a: <http://foo/a#> . a:b a:oneRef [ a:pp "1" ; a:qq "2" ] .)
        nt = %(
        _:bnode0 <http://foo/a#pp> "1" .
        _:bnode0 <http://foo/a#qq> "2" .
        <http://foo/a#b> <http://foo/a#oneRef> _:bnode0 .
        )
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end
      
      it "should create a shared BNode" do
        n3 = %(
        @prefix a: <http://foo/a#> .

        a:b1 a:twoRef _:a .
        a:b2 a:twoRef _:a .

        _:a :pred [ a:pp "1" ; a:qq "2" ].
        )
        nt = %(
        <http://foo/a#b1> <http://foo/a#twoRef> _:a .
        <http://foo/a#b2> <http://foo/a#twoRef> _:a .
        _:bnode0 <http://foo/a#pp> "1" .
        _:bnode0 <http://foo/a#qq> "2" .
        _:a :pred _:bnode0 .
        )
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end
      
      it "should create nested BNodes" do
        n3 = %(
        @prefix a: <http://foo/a#> .

        a:a a:p [ a:p2 [ a:p3 "v1" , "v2" ; a:p4 "v3" ] ; a:p5 "v4" ] .
        )
        nt = %(
        _:bnode0 <http://foo/a#p3> "v1" .
        _:bnode0 <http://foo/a#p3> "v2" .
        _:bnode0 <http://foo/a#p4> "v3" .
        _:bnode1 <http://foo/a#p2> _:bnode0 .
        _:bnode1 <http://foo/a#p5> "v4" .
        <http://foo/a#a> <http://foo/a#p> _:bnode1 .
        )
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end

      describe "from paths" do
        it "should create bnode for path x.p" do
          n3 = %(:x2.:y2 :p2 "3" .)
          nt = %(:x2 :y2 _:bnode0 . _:bnode0 :p2 "3" .)
          parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
        end
      
        it "should create bnode for path x!p" do
          n3 = %(:x2!:y2 :p2 "3" .)
          nt = %(:x2 :y2 _:bnode0 . _:bnode0 :p2 "3" .)
          parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
        end
      
        it "should create bnode for path x^p" do
          n3 = %(:x2^:y2 :p2 "3" .)
          nt = %(_:bnode0 :y2 :x2 . _:bnode0 :p2 "3" .)
          parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
        end
      
        it "should decode :joe!fam:mother!loc:office!loc:zip as Joe's mother's office's zipcode" do
          n3 = %(
          @prefix fam: <http://foo/fam#> .
          @prefix loc: <http://foo/loc#> .

          :joe!fam:mother!loc:office!loc:zip .
          )
          nt = %(
          :joe <http://foo/fam#mother> _:bnode0 .
          _:bnode0 <http://foo/loc#office> _:bnode1 .
          _:bnode1 <http://foo/loc#zip> _:bnode2 .
          )
          parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
        end

        it "should decode :joe!fam:mother^fam:mother Anyone whose mother is Joe's mother." do
          n3 = %(
          @prefix fam: <http://foo/fam#> .
          @prefix loc: <http://foo/loc#> .

          :joe!fam:mother^fam:mother .
          )
          nt = %(
          :joe <http://foo/fam#mother> _:bnode0 .
          _:bnode1 <http://foo/fam#mother> _:bnode0 .
          )
          parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
        end

        it "should decode path with property list." do
          n3 = %(
          @prefix a: <http://a/ns#>.
          :a2.a:b2.a:c2 :q1 "3" ; :q2 "4" , "5" .
          )
          nt = %(
          :a2 <http://a/ns#b2> _:bnode0 .
          _:bnode0 <http://a/ns#c2> _:bnode1 .
          _:bnode1 :q1 "3" .
          _:bnode1 :q2 "4" .
          _:bnode1 :q2 "5" .
          )
          parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
        end

        it "should decode path as object(1)" do
          n3 = %(:a  :b "lit"^:c.)
          nt = %(
            :a :b _:bnode .
            _:bnode :c "lit" .
          )
          parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
        end

        it "should decode path as object(2)" do
          n3 = %(@prefix a: <http://a/ns#>. :r :p :o.a:p1.a:p2 .)
          nt = %(
          :o <http://a/ns#p1> _:bnode0 .
          _:bnode0 <http://a/ns#p2> _:bnode1 .
          :r :p _:bnode1 .
          )
          parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
        end
      end
    end
    
    describe "formulae" do
      it "should require that graph be formula_aware when encountering a formlua"
      
      it "should separate triples between specified and quoted graphs"
    end
    
    describe "object lists" do
      it "should create 2 statements for simple list" do
        n3 = %(:a :b :c, :d)
        nt = %(<http://a/b#a> <http://a/b#b> <http://a/b#c> . <http://a/b#a> <http://a/b#b> <http://a/b#d> .)
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end
    end
    
    describe "property lists" do
      it "should parse property list" do
        n3 = %(
        @prefix a: <http://foo/a#> .

        a:b a:p1 "123" ; a:p1 "456" .
        a:b a:p2 a:v1 ; a:p3 a:v2 .
        )
        nt = %(
        <http://foo/a#b> <http://foo/a#p1> "123" .
        <http://foo/a#b> <http://foo/a#p1> "456" .
        <http://foo/a#b> <http://foo/a#p2> <http://foo/a#v1> .
        <http://foo/a#b> <http://foo/a#p3> <http://foo/a#v2> .
        )
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end
    end
    
    describe "lists" do
      it "should parse empty list" do
        n3 = %(@prefix :<http://example.com/>. :empty :set ().)
        nt = %(
        <http://example.com/empty> <http://example.com/set> <http://www.w3.org/1999/02/22-rdf-syntax-ns#nil> .)
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end
      
      it "should parse list with single element" do
        n3 = %(@prefix :<http://example.com/>. :gregg :wrote ("RdfContext").)
        nt = %(
        _:bnode0 <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> "RdfContext" .
        _:bnode0 <http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> <http://www.w3.org/1999/02/22-rdf-syntax-ns#nil> .
        <http://example.com/gregg> <http://example.com/wrote> _:bnode0 .
        )
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end
      
      it "should parse list with multiple elements" do
        n3 = %(@prefix :<http://example.com/>. :gregg :name ("Gregg" "Barnum" "Kellogg").)
        nt = %(
        _:bnode0 <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> "Gregg" .
        _:bnode0 <http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> _:bnode1 .
        _:bnode1 <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> "Barnum" .
        _:bnode1 <http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> _:bnode2 .
        _:bnode2 <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> "Kellogg" .
        _:bnode2 <http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> <http://www.w3.org/1999/02/22-rdf-syntax-ns#nil> .
        <http://example.com/gregg> <http://example.com/name> _:bnode0 .
        )
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end
      
      it "should parse unattached lists" do
        n3 = %(
        @prefix a: <http://foo/a#> .

        ("1" "2" "3") .
        # This is not a statement.
        () .
        )
        nt = %(
        _:bnode0 <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> "1" .
        _:bnode0 <http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> _:bnode1 .
        _:bnode1 <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> "2" .
        _:bnode1 <http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> _:bnode2 .
        _:bnode2 <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> "3" .
        _:bnode2 <http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> <http://www.w3.org/1999/02/22-rdf-syntax-ns#nil> .
        )
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end
      
      it "should add property to nil list" do
        n3 = %(@prefix a: <http://foo/a#> . () a:prop "nilProp" .)
        nt = %(<http://www.w3.org/1999/02/22-rdf-syntax-ns#nil> <http://foo/a#prop> "nilProp" .)
        parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
      end
      it "should parse with compound items" do
        n3 = %(
        @prefix a: <http://foo/a#> .

        a:a a:p ( [ a:p2 "v1" ] 
        	  <http://resource1>
        	  <http://resource2>
        	  ("inner list") ) .

        <http://resource1> a:p "value" .
        )
        nt = %(
        <http://foo/a#a> <http://foo/a#p> _:bnode5 .
        _:bnode5 <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> _:bnode4 .
        _:bnode5 <http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> _:bnode2 .
        _:bnode4 <http://foo/a#p2> "v1" .
        _:bnode2 <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> <http://resource1> .
        <http://resource1> <http://foo/a#p> "value" .
        _:bnode2 <http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> _:bnode1 .
        _:bnode1 <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> <http://resource2> .
        _:bnode1 <http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> _:bnode0 .
        _:bnode0 <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> _:bnode3 .
        _:bnode0 <http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> <http://www.w3.org/1999/02/22-rdf-syntax-ns#nil> .
        _:bnode3 <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> "inner list" .
        _:bnode3 <http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> <http://www.w3.org/1999/02/22-rdf-syntax-ns#nil> .
        )
        g = parse(n3, :base_uri => "http://a/b")
        normalize_bnodes(g, "bnode0").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug, :compare => :array)
      end
      
    end
    
     # n3p tests taken from http://inamidst.com/n3p/test/
    describe "with real data tests" do
      dirs = %w(misc lcsh rdflib n3p)
      dirs.each do |dir|
        dir_name = File.join(File.dirname(__FILE__), '..', 'test', 'n3_tests', dir, '*.n3')
        Dir.glob(dir_name).each do |n3|
          it "#{dir} #{n3}" do
            test_file(n3)
          end
        end
      end
    end

    describe "with AggregateGraph tests" do
      describe "with a type" do
        it "should have 3 namespaces" do
          n3 = %(
          @prefix rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
          @prefix : <http://test/> .
          :foo a rdfs:Class.
          :bar :d :c.
          :a :d :c.
          )
          nt = %(
          <http://test/foo> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2000/01/rdf-schema#Class> .
          <http://test/bar> <http://test/d> <http://test/c> .
          <http://test/a> <http://test/d> <http://test/c> .
          )
          parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
        end
      end
    
      describe "with blank clause" do
        it "should have 4 namespaces" do
          n3 = %(
          @prefix rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
          @prefix : <http://test/> .
          @prefix log: <http://www.w3.org/2000/10/swap/log#>.
          :foo a rdfs:Resource.
          :bar rdfs:isDefinedBy [ a log:Formula ].
          :a :d :e.
          )
          nt = %(
          <http://test/foo> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2000/01/rdf-schema#Resource> .
          _:g2160128180 <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2000/10/swap/log#Formula> .
          <http://test/bar> <http://www.w3.org/2000/01/rdf-schema#isDefinedBy> _:g2160128180 .
          <http://test/a> <http://test/d> <http://test/e> .
          )
          parse(n3, :base_uri => "http://a/b").should be_equivalent_graph(nt, :about => "http://a/b", :trace => @debug)
        end
      end
    
      describe "with empty subject" do
        before(:each) do
          @graph = parse(%(
          @prefix rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
          @prefix log: <http://www.w3.org/2000/10/swap/log#>.
          @prefix : <http://test/> .
          <> a log:N3Document.
          ), :base_uri => "http://test/")
        end
        
        it "should have 4 namespaces" do
          nt = %(
          <http://test/> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2000/10/swap/log#N3Document> .
          )
          @graph.should be_equivalent_graph(nt, :about => "http://test/", :trace => @debug)
        end
        
        it "should have default subject" do
          @graph.size.should == 1
          @graph.statements.first.subject.to_s.should == "http://test/"
        end
      end
    end
  end

  it "should parse rdf_core testcase" do
    sampledoc = <<-EOF;
<http://www.w3.org/2000/10/rdf-tests/rdfcore/xmlbase/Manifest.rdf#test001> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#PositiveParserTest> .
<http://www.w3.org/2000/10/rdf-tests/rdfcore/xmlbase/Manifest.rdf#test001> <http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#approval> <http://lists.w3.org/Archives/Public/w3c-rdfcore-wg/2002Mar/0235.html> .
<http://www.w3.org/2000/10/rdf-tests/rdfcore/xmlbase/Manifest.rdf#test001> <http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#inputDocument> <http://www.w3.org/2000/10/rdf-tests/rdfcore/xmlbase/test001.rdf> .
<http://www.w3.org/2000/10/rdf-tests/rdfcore/xmlbase/Manifest.rdf#test001> <http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#issue> <http://www.w3.org/2000/03/rdf-tracking/#rdfms-xml-base> .
<http://www.w3.org/2000/10/rdf-tests/rdfcore/xmlbase/Manifest.rdf#test001> <http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#outputDocument> <http://www.w3.org/2000/10/rdf-tests/rdfcore/xmlbase/test001.nt> .
<http://www.w3.org/2000/10/rdf-tests/rdfcore/xmlbase/Manifest.rdf#test001> <http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#status> "APPROVED" .
<http://www.w3.org/2000/10/rdf-tests/rdfcore/xmlbase/test001.nt> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#NT-Document> .
<http://www.w3.org/2000/10/rdf-tests/rdfcore/xmlbase/test001.rdf> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#RDF-XML-Document> .
EOF
    graph = parse(sampledoc, :base_uri => "http://www.w3.org/2000/10/rdf-tests/rdfcore/amp-in-url/Manifest.rdf")

    graph.should be_equivalent_graph(sampledoc,
      :about => "http://www.w3.org/2000/10/rdf-tests/rdfcore/amp-in-url/Manifest.rdf",
      :trace => @debug
    )
  end
  
  def parse(input, options = {})
    @debug = []
    graph = RDF::Graph.new
    RDF::N3::Reader.new(input, options.merge(:debug => @debug, :strict => true)).each do |statement|
      graph << statement
    end
    graph
  end

  def test_file(filepath)
    n3_string = File.read(filepath)
    @graph = parse(File.open(filepath), :base_uri => "file:#{filepath}")

    nt_string = File.read(filepath.sub('.n3', '.nt'))
    @graph.should be_equivalent_graph(nt_string,
      :about => "file:#{filepath}",
      :trace => @debug)
  end
end
