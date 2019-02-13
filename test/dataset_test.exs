defmodule DatasetTest do
  use ExUnit.Case

  alias NimbleCSV.RFC4180, as: CSV
  alias Nomure.Node
  alias Nomure.Schema.{ParentNode, ChildrenNode}
  alias Nomure.Schema.Query.{ParentQuery}

  @schema %{
    "movies" => %{
      "movie_id" => %{
        "type" => "integer",
        "index" => true
      },
      "adult" => %{
        "type" => "boolean"
      },
      "belongs_to_collection" => %{
        "type" => "string"
      },
      "budget" => %{
        "type" => "integer"
      },
      "genres" => %{
        "type" => "string"
      },
      "homepage" => %{
        "type" => "string",
        "index" => ["unique"]
      },
      "id" => %{
        "type" => "integer"
      },
      "imdb_id" => %{
        "type" => "string"
      },
      "original_language" => %{
        "type" => "string"
      },
      "original_title" => %{
        "type" => "string"
      },
      "overview" => %{
        "type" => "string"
      },
      "popularity" => %{
        "type" => "string"
      },
      "poster_path" => %{
        "type" => "string"
      },
      "production_companies" => %{
        "type" => "string"
      },
      "production_countries" => %{
        "type" => "string"
      },
      "release_date" => %{
        "type" => "string"
      },
      "revenue" => %{
        "type" => "integer"
      },
      "runtime" => %{
        "type" => "string"
      },
      "spoken_languages" => %{
        "type" => "string"
      },
      "status" => %{
        "type" => "string"
      },
      "tagline" => %{
        "type" => "string"
      },
      "title" => %{
        "type" => "string",
        "index" => ["exact"]
      },
      "video" => %{
        "type" => "boolean"
      },
      "vote_average" => %{
        "type" => "float"
      },
      "vote_count" => %{
        "type" => "integer"
      }
    },
    "users" => %{
      "user_id" => %{
        "type" => "integer",
        "index" => true
      },
      "movies" => %{
        "type" => "node_list"
      }
    }
  }

  @tag :expensive
  setup_all do
    :os.cmd(~S"fdbcli --exec \"writemode on; clearrange \x00 \xff;\"" |> String.to_charlist())

    Nomure.Database.set_schema(@schema)

    ratings = parse_ratings()
    movies = parse_movies()

    IO.puts("Inserting movie data - Start time #{NaiveDateTime.utc_now()}")

    # create movies nodes, save map with id
    movie_ids =
      movies
      |> Task.async_stream(
        fn
          movie ->
            movie = Map.put_new(movie, :movie_id, movie.id)

            data = %ParentNode{
              node_name: "movies",
              node_data: movie
            }

            {{_node_name, uid}, _relation_uids} = Node.create_node(data)

            {movie.movie_id, uid}
        end,
        max_concurrency: 100
      )
      |> Enum.to_list()
      |> Map.new()

    IO.puts("\t Movie data inserted - Ended time #{NaiveDateTime.utc_now()}")

    IO.puts("Perpare user data - Start time #{NaiveDateTime.utc_now()}")
    # create users nodes, save map with id
    user_parent_nodes =
      ratings
      |> Enum.uniq_by(fn %{user_id: id} -> id end)
      |> Enum.map(fn
        %{
          user_id: user_id,
          movie_id: _movie_id,
          rating: _rating,
          timestamp: _timestamp
        } ->
          user_movies =
            ratings
            |> Enum.filter(fn %{user_id: u_id} -> u_id === user_id end)
            |> Enum.map(fn %{movie_id: movie_id, rating: rating, timestamp: timestamp} ->
              %ChildrenNode{
                node_data: Map.get(movie_ids, movie_id),
                node_name: "movies",
                edge_data: %{rating: rating, timestamp: timestamp}
              }
            end)
            |> Enum.reject(fn %ChildrenNode{node_data: n_data} -> is_nil(n_data) end)

          %ParentNode{
            node_name: "users",
            node_data: %{
              user_id: user_id
            },
            node_relationships: %{
              movies: user_movies
            }
          }
      end)

    IO.puts("\t User parent nodes created - Ended time #{NaiveDateTime.utc_now()}")

    IO.puts("Start user insert - Start time #{NaiveDateTime.utc_now()}")

    user_parent_nodes
    |> Task.async_stream(
      fn
        %{
          node_data: %{
            user_id: user_id
          }
        } = parent_node ->
          {{_node_name, uid}, _relation_uids} = Node.create_node(parent_node)

          {user_id, uid}
      end,
      max_concurrency: 100
    )
    |> Enum.to_list()
    |> Map.new()

    IO.puts("\t User data inserted - End time #{NaiveDateTime.utc_now()}")

    {:ok, %{users_length: user_parent_nodes |> length()}}
  end

  @tag :expensive
  test "get movie by name", _state do
    lookup_result =
      Node.query(%ParentQuery{
        node_name: "movies",
        where: %{
          title: "Toy Story"
        },
        select: [
          :genres,
          :adult,
          :original_language,
          :popularity
        ]
      })

    assert lookup_result == [
             %{
               adult: false,
               genres:
                 "[{'id': 16, 'name': 'Animation'}, {'id': 35, 'name': 'Comedy'}, {'id': 10751, 'name': 'Family'}]",
               original_language: "en",
               popularity: "21.946943"
             }
           ]
  end

  @tag :expensive
  test "length correctness", %{users_length: users_length} do
    lookup_result =
      Node.query(%ParentQuery{
        node_name: "users",
        where: %{
          user_id_gte: 0
        },
        select: [
          :id
        ]
      })
      |> length()

    assert lookup_result == users_length
  end

  def parse_ratings do
    Path.join([:code.priv_dir(:nomure), "dataset", "ratings_small.csv"])
    |> File.stream!()
    |> CSV.parse_stream()
    |> Stream.map(fn [user_id, movie_id, rating, timestamp] ->
      %{
        user_id: String.to_integer(user_id),
        movie_id: String.to_integer(movie_id),
        rating: String.to_float(rating),
        timestamp: String.to_integer(timestamp)
      }
    end)
    |> Enum.to_list()
  end

  def parse_movies do
    Path.join([:code.priv_dir(:nomure), "dataset", "movies_metadata.csv"])
    |> File.stream!()
    |> CSV.parse_stream()
    |> Stream.map(fn
      [
        adult,
        belongs_to_collection,
        budget,
        genres,
        homepage,
        id,
        imdb_id,
        original_language,
        original_title,
        overview,
        popularity,
        poster_path,
        production_companies,
        production_countries,
        release_date,
        revenue,
        runtime,
        spoken_languages,
        status,
        tagline,
        title,
        video,
        vote_average,
        vote_count
      ] ->
        %{
          adult: to_boolean(adult),
          belongs_to_collection: belongs_to_collection,
          budget: String.to_integer(budget),
          genres: genres,
          homepage: homepage,
          id: String.to_integer(id),
          imdb_id: imdb_id,
          original_language: original_language,
          original_title: original_title,
          overview: overview,
          popularity: popularity,
          poster_path: poster_path,
          production_companies: production_companies,
          production_countries: production_countries,
          release_date: release_date,
          revenue: String.to_integer(revenue),
          runtime: runtime,
          spoken_languages: spoken_languages,
          status: status,
          tagline: tagline,
          title: title,
          video: to_boolean(video),
          vote_average: String.to_float(vote_average),
          vote_count: String.to_integer(vote_count)
        }

      _ ->
        nil
    end)
    |> Enum.to_list()
    # reject bad formated data
    |> Enum.reject(&is_nil/1)
  end

  defp to_boolean("False") do
    false
  end

  defp to_boolean("True") do
    true
  end
end
